# SNSF Grant Similarity

This repository contains implementation of text similarity methods for SNSF grants. It consists of two parts:

- `/swisstext`: codes for matching grant proposals to reviewers based on text similarity
- `/notebooks`: tutorials for text similarity methods to retrieve similar grants

## Overview

The SNSF supports scientific research by evaluating grant proposals and deciding which of them are eligible for funding. As a part of the evaluation procedure, submitted grant proposals need to be assigned to suitable reviewers who assess the scientific quality of the proposals. We define this task as a text similarity problem to leverage the benefits of natural language processing to pre-filter a subset of suitable reviewers from a pre-defined pool of expert reviewers. In particular, we vectorize the texts of proposals and those of reviewers' publications and compute their similarity. For each proposal we then rank-order the similarity scores of all potential reviewers to retrieve the subset of best-matching reviewers. This subset then serves the scientific officers as a pre-filtered set of suitable reviewers. The SNSF is testing these algorithms to help with the assignment of grant proposals to evaluation panel members from a pre-defined pool of expert reviewers.

## SwissText

As the choice of the text vectorization method for the text similarity is not *a priori* clear,
we investigate the performance of BERT transformer models vs. classical bag-of-words approach using TF-IDF in the following research paper:

**The Value of Pre-training for Scientific Text Similarity: Evidence from Matching Grant Proposals to Reviewers**

submitted to the 9th Swiss Text Analytics Conference [SwissText](https://www.swisstext.org/). The [paper](https://www.swisstext.org/wp-content/uploads/2024/06/Proceedings_Preprint.pdf#99) is available as a preprint of the conference proceedings as well as a [poster](https://github.com/snsf-data/snsf-grant-similarity/tree/main/swisstext/output/snsf_swisstext_poster.pdf) presentation.

The subfolder `/swisstext` contains the description and the codes for the conducted analyses.

## Notebooks

In order to showcase the implementation of the text similarity methods, the notebooks provide tutorials for a word embeddings approach via pre-trained transformer model as well as for a bag-of-words approach via TF-IDF to retrieve similar grants based on the textual data provided in grant titles and abstracts, which is publicly available through the SNSF Data Portal: [data.snf.ch](https://data.snf.ch/).

The subfolder `/notebooks` contains the description and the codes for the implemented text vectorization methods.

## Contact

If you have questions regarding the SwissText paper or the tutorial notebooks, please contact [gabriel.okasa@snf.ch](mailto:gabriel.okasa@snf.ch). For general inquiries about the SNSF Data Portal, please contact [datateam@snf.ch](mailto:datateam@snf.ch).

## License

MIT © snsf-data

