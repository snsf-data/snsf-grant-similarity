# SNSF Grant Similarity: SwissText

This repository contains the codes for the analyses conducted in the research paper titled

**The Value of Pre-training for Scientific Text Similarity: Evidence from Matching Grant Proposals to Reviewers**

submitted to the 9th Swiss Text Analytics Conference [SwissText](https://www.swisstext.org/). The [paper](https://www.swisstext.org/wp-content/uploads/2024/06/Proceedings_Preprint.pdf#99) is available as a preprint of the conference proceedings as well as a [poster](https://github.com/snsf-data/snsf-grant-similarity/tree/main/swisstext/output/snsf_swisstext_poster.pdf) presentation.

Authors: Gabriel Okasa ([@okasag](https://github.com/okasag)) \& Anne Jorstad ([@ajorstad](https://github.com/ajorstad))

## Abstract

Matching grant proposals to reviewers is a core task for research funding agencies. We approach
this task as a text similarity problem to allow pre-filtering of a relevant subset of potential
matches using pre-trained language models. Given the scientific nature of our English text corpus,
we investigate the value of targeted pre-training of BERT models towards scientific documents for
the matching task based on the text similarity. We benchmark the performance of BERT models with
a classical bag-of-words approach using TF-IDF. The results reveal a clear benefit from pre-training
BERT on scientific texts and additionally augmenting by citation graphs. Interestingly, the BERT models
do not substantially out-perform TF-IDF on the texts from any discipline. The results are robust to
various types of input data and modelling choices.

## Code

The codes rely on both `R` and `Python` and are structured as follows:

- `swisstext.Rproj`: RStudio project file storing project options
- `def_script.R`: main script defining the parameters and executing the analyses
- `report.Rmd`: Rmarkdown file producing `.pdf` and `.tex` outputs for the final report
- `R/`: subfolder containing all modular `R` scripts sourced directly from `def_script.R`
- `python/`: subfolder containing `python` script sourced directly from `def_script.R`
- `data/`: subfolder containing folder structure for data inputs and outputs
- `output/`: subfolder containing the `.pdf` and `.tex` reports with results

In order to conduct the analyses, it is sufficient to run `def_script.R` which executes
the full pipeline and produces the final report. Within `def_script.R` setting `method_selection <- "transformers"`
produces the results for the BERT models, while setting `method_selection <- "tfidf"` will produce the
results for the TF-IDF models. Given the modular structure of the code, it should be feasible to adapt it, or its parts, for similar text analysis projects.

Please note that due to data protection laws, the data cannot be shared. In order to provide a working example,
please refer to the [notebooks](https://github.com/snsf-data/snsf-grant-similarity/tree/main/notebooks) which showcase the analyses based on publicly available data from the SNSF Data Portal: [data.snf.ch](https://data.snf.ch/).

## Contact

If you have questions regarding the paper or the codes, please contact [gabriel.okasa@snf.ch](mailto:gabriel.okasa@snf.ch).
For general inquiries about the SNSF Data Portal, please contact [datateam@snf.ch](mailto:datateam@snf.ch).

## License

MIT © snsf-data

