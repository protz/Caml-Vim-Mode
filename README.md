OCaml Vim Mode
==============

This is a quick hack that allows you to edit phrases in a vim buffer and send
phrases under the cursor to a running ocaml session. Should work with a recent
vim.

Warning: this is just a hack, don't expect it to work properly.

Usage
=====

F2 starts a vim-ocaml session

Edit the top buffer.

F3 sends the current phrase to the vim session that's running in the background.

Bugs
====

Currently, this will kill any ocaml and tail processes running. Beware!
