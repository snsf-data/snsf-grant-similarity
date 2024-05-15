# ---------------------------------------------------------------------------- #
# Extract Text Embeddings via Transformers for Applicants' and Reviewers' Texts
# ---------------------------------------------------------------------------- #

# import modules
import os
import torch
import transformers
import sklearn
import platform

import pandas as pd
import numpy as np

from torch.nn import functional

# ---------------------------------------------------------------------------- #
# define mean pooling function as defined in sentence-transformers
# see: https://huggingface.co/sentence-transformers/all-mpnet-base-v2
def mean_pooling(model_output, attention_mask, normalize=True):
    # First element of model_output contains all token embeddings
    token_embeddings = model_output[0]
    # expand attention mask to the same dimensions as the embeddings [1, 512, 768]
    input_mask_expanded = attention_mask.unsqueeze(-1).expand(token_embeddings.size()).float()
    # compute the average only over tokens covered by the attention mask (0,1), average over dim=1, i.e. the 512 tokens
    token_average = torch.sum(token_embeddings * input_mask_expanded, 1) / torch.clamp(input_mask_expanded.sum(1), min=1e-9)
    # normalize the embeddings with L2 norm - cosine similarity can be then computed only using the dot product
    if normalize:
            # L2 norm
            token_average = functional.normalize(token_average, p=2, dim=1)
    # return the mean pooled tokens as text embedding in numpy format
    return token_average.detach().to('cpu').numpy()

# ---------------------------------------------------------------------------- #
# define mean extraction of the CLS token representing text as a whole
def extract_cls(model_output, normalize=True):
    # First element of model_output contains all token embeddings
    token_embeddings = model_output[0]
    # extract the first out of 512 tokens, i.e. the so-called CLS token (torch dimension: [1,512,768])
    cls_token = token_embeddings[:,0,:]
    # normalize the embeddings with L2 norm - cosine similarity can be then computed only using the dot product
    if normalize:
            # L2 norm
            cls_token = functional.normalize(cls_token, p=2, dim=1)
    # return the CLS token as text embedding in a numpy format
    return cls_token.detach().to('cpu').numpy()

# ---------------------------------------------------------------------------- #
# detect OS
current_os = platform.system()
# active device based on OS
if current_os == "Darwin":
    # specify device as mps
    device = "mps"
else:
    # check if gpu is available, if yes use cuda, if not stick to cpu
    if torch.cuda.is_available():
        device = torch.device("cuda:0") # must be 'cuda:0', not just 'cuda' due to a bug in transformers library, see: https://github.com/deepset-ai/haystack/issues/3160
        print('GPU', torch.cuda.get_device_name(0), 'is available and will be used as a device.')
    else:
        device = torch.device("cpu")

# ---------------------------------------------------------------------------- #
# import text data
texts = pd.read_csv(os.getcwd() + "/python/data/text_data.csv")
# ensure string type for all texts
texts.text_data = texts.text_data.astype(str)
# convert to lower case
texts.text_data = texts.text_data.map(str.lower)
# convert data into list
text_data = texts.text_data.to_list()

# ---------------------------------------------------------------------------- #
# import model params
model_params = pd.read_csv(os.getcwd() + "/python/data/model_params.csv")
# keep only the string of the name and token and truncation side
model_name = model_params.name[0]
model_token = model_params.token[0]
model_truncation = model_params.truncation[0]

# ---------------------------------------------------------------------------- #
# specify tokenizer and model
tokenizer = transformers.AutoTokenizer.from_pretrained(model_name, truncation_side=model_truncation)
# set model and specify the device for computation
model = transformers.AutoModel.from_pretrained(model_name).to(device)

# ---------------------------------------------------------------------------- #
# specify batch size
batch_size = 1000 # optimal for speed performance
# calculate number of batches and last batch size
n_batches = int(np.ceil(len(text_data) / batch_size))
last_batch = int(len(text_data) % batch_size)
# create storage for results  (768 embeddings dimension)
full_embeddings = pd.DataFrame(columns=['index'] + [x for x in range(768)] + ['index', 'doc_id'])

# do the tokenizing + embedding in batches of 1000s for better performance
for batch_idx in range(n_batches):

    # print current batch number
    print("Processing batch n.: ", str(batch_idx), "\n")

    # get batch of text_data, depnding if last batch is being processed or not
    if (batch_idx == n_batches - 1):
        # take the last samples
        text_data_batch = text_data[batch_idx*batch_size:(batch_idx*batch_size)+last_batch]
        # get the corrsponding doc id
        doc_id_batch = pd.DataFrame(texts.doc_id.iloc[batch_idx*batch_size:(batch_idx*batch_size)+last_batch])
        # placeholder for encoded texts
        encoded_text = list(range(last_batch))
    else:
        # take full batch samples
        text_data_batch = text_data[batch_idx*batch_size:(batch_idx+1)*batch_size]
        # get the corrsponding doc id
        doc_id_batch = pd.DataFrame(texts.doc_id.iloc[batch_idx*batch_size:(batch_idx+1)*batch_size])
        # placeholder for encoded texts
        encoded_text = list(range(batch_size))

    # tokenize the texts
    for text_idx in range(len(encoded_text)):
        # and send it to device
        encoded_text[text_idx] = tokenizer(text_data_batch[text_idx],
                                        max_length=512,
                                        truncation=True,
                                        padding='max_length',
                                        return_tensors = "pt"
                                        ).to(device)
        
    # placeholder for embeddings
    embeddings = list(range(len(encoded_text)))
    # extract embeddings (mean of all tokens vs. CLS token)
    for text_idx in range(len(encoded_text)):
        # first get the model output
        with torch.no_grad():
            model_output = model(**encoded_text[text_idx])
        
        # then decide based on which token the embeddings should be extracted
        if model_token == 'cls_token':
            # extract the first CLS token of the 512 ones
            embeddings[text_idx] = extract_cls(model_output, normalize=True)
        else:
            # mean pooling of tokens
            embeddings[text_idx] = mean_pooling(model_output, attention_mask=encoded_text[text_idx]['attention_mask'], normalize=True)

    # save the batch results cumulatively
    batch_embeddings = pd.concat([pd.DataFrame(np.concatenate(embeddings)).reset_index(), doc_id_batch.reset_index()], axis=1)
    # and add the to full embeddings
    full_embeddings = pd.concat([full_embeddings, batch_embeddings], axis=0)
    full_embeddings.drop('index', axis=1).to_csv(os.getcwd() + "/python/data/embeddings.csv", index=False)

# ---------------------------------------------------------------------------- #
# save the full embeddings after batches were processed completely
full_embeddings.drop('index', axis=1).to_csv(os.getcwd() + "/python/data/embeddings.csv", index=False)

# ---------------------------------------------------------------------------- #
