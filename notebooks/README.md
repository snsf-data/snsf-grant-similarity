# SNSF Grant Similarity: Notebooks

This repository contains notebooks for implementation of text similarity methods for SNSF grants.

## Overview

The notebooks provide a demonstration of applying natural language processing tools in `Python` to retrieve similar grants
based on the textual data provided in grant titles and abstracts, which is publicly available through the
SNSF Data Portal: [data.snf.ch](https://data.snf.ch/). The notebooks showcase two particular text vectorization approaches
to convert text data into a numerical representation:

- **Bag-of-Words** via TF-IDF
- **Word Embeddings** via Transformers

Based on the numerical text representations, text similarity is computed via the cosine distance among the text vectors.
Given the similarity matrix, pairs of most similar grants can be retrieved. The end-to-end pipeline can be summarized in the
following steps:

1. Download of publicly available text data from the SNSF data portal: [data.snf.ch](https://data.snf.ch/)
2. Cleaning and pre-processing of the text data
3. Application of text vectorization method to get numerical representations of the text
4. Computation of the cosine similarity scores
5. Retrieval of the most similar grants based on rank-ordering the similarity scores

The notebooks include the code and a detailed description of the text analysis.

## Replication

To clone the repository run:

```
git clone https://github.com/snsf-data/snsf-grant-similarity.git
```

The required `Python` modules can be installed by navigating to the subfolder `notebooks/` of
the cloned project and executing the following command: `pip install -r requirements.txt`.
The implementation relies on `Python` version 3.9.12.

## Contact

If you have questions regarding the notebooks, please contact [gabriel.okasa@snf.ch](mailto:gabriel.okasa@snf.ch).
For general inquiries about the SNSF Data Portal, please contact [datateam@snf.ch](mailto:datateam@snf.ch).

## License

MIT © snsf-data

