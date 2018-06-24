[![Build Status](https://travis-ci.org/akirak/helm-tail.svg?branch=master)](https://travis-ci.org/akirak/helm-tail)

# helm-tail

`helm-tail` is a Helm interface for browsing recent items from special buffers such as `*Backtrace*`, `*compilation*`, `*Messages*`, etc. You can use it to remember a recent error in Emacs with a single command. You can use `C-c TAB` to insert an error message into the current buffer, and `C-c C-k` to save it in the kill ring.

You can customize the list of sources with `helm-tail-sources` variable.
