---
author: Antonio Pantaleo
title: How git aliases can save you hours of time
date: 2023-05-17T19:39:19+02:00
tags: ["git"]
---

Imagine a coding world where you can navigate your Git repository, commit changes, and handle merges and branches at lightning speed.

<!--more-->

## What are aliases
Aliases are a faster way to execute a command. They are *shortcuts* for longer commands. Imagine typing **every time** a command like `git push origin master`. You can type it *999* times, but by the *1000*th time you feel tired. What if you can just use initials?

`gpom` (**g**it **p**ush **o**rigin **m**aster)
 
Wouldn't that be great? Aliases let you just do that. Personally, I make use of two distinct types of aliases:

- **git aliases**: stored in `.gitconfig`. You can call them using `git <name-of-the-alias>`
- **shell aliases**: stored in the shell configuration file (e.g., `bashrc` or `.zshrc`). You can call them like a native command (like `gpom`!)

Here are some aliases I use daily[^images]:

#### gss
Stands for **g**it **s**tatus **s**hort. It lets me see the status of my repository at a glance
```bash
alias gss="git status --short"
```
![git status short](/blog/how-git-aliases-can-save-you-hours-of-time/gss.png)


#### gshsm
Stands for **g**it **s**ta**sh** **m**essage (letters are swapped for faster typing). It lets me create a new stash with a custom message
```bash
alias gshsm="git stash -m"
```

#### gshsl
Stands for **g**it **s**ta**sh** **l**ist (letters are swapped for faster typing). It lets me list all saved stashes
```bash
alias gshsl="git stash list"
```

#### gls
Stands for **g**it **ls** (or *git list*). It works like the standard `ls`, but for repos. It lets me list all files in a specific branch (or commit). I usually combine it with `grep`
```bash
alias gls="git ls-tree -r --name-only"
```
![git list](/blog/how-git-aliases-can-save-you-hours-of-time/gls.png)

#### glg
Stands for **g**it **l**og **g**lobal (or **g**it **l**og **g**raph, I can't decide). It shows me commit graph for *all* branches

```bash
glg () {
    git log \
        --format=format:"%C(bold yellow)%h%C(auto)%d ~ %C(blue)[%cD]%C(reset)%n    %C(white)%s%C(reset)%C(dim white) • %an%C(reset)%C(green)" \
        --all \
        --graph \
        --abbrev-commit \
        --decorate \
        --topo-order \
        --date-order
}
```
How it looks like:
![git log global](/blog/how-git-aliases-can-save-you-hours-of-time/glg.png)

#### glf[^diffr]
Stands for **g**it **l**og **f**uzzy-finder[^fuzzy]. A commit search-engine. I can filter commit by commit message, and see a preview on the right. If I hit `enter` I can open the full diff
```bash
_gitLogLineToHash="echo {} | grep -o '[a-f0-9]\{7\}' | head -1"
_diffrCommand="diffr \
    --line-numbers \
    --colors refine-added:none:background:51,153,51:bold \
    --colors added:none:background:51,85,51 \
    --colors refine-removed:none:background:191,97,106:bold \
    --colors removed:none:background:85,51,51"
_viewGitLogLine="$_gitLogLineToHash | xargs -I % sh -c 'git show -p --color=always %'"

glf () {
    git log \
        --color=always \
        --format="%C(bold yellow)%h %C(reset)%s %C(reset)%C(blue)[%cr]" "$@" |
        fzf -i -e \
        --no-sort \
        --reverse \
        --tiebreak=index \
        --no-multi \
        --ansi \
        --header="control-y: copy hash" \
        --preview="git show -p --color=always {1} | $_diffrCommand | less -R" \
        --bind="enter:execute:$_viewGitLogLine | $_diffrCommand | less -R" \
        --bind="ctrl-y:execute:$_gitLogLineToHash | pbcopy" 
}
```
![git log fuzzy](/blog/how-git-aliases-can-save-you-hours-of-time/glf.png)

#### git lost-stashes
This is self-explanatory. It lets you find stashes that you deleted or accidentally dropped (yeah, you can do it)
```bash
# ~/.gitconfig
[alias]
    lost-stashes = !LANG=en_GB git fsck \
        --unreachable \
        --no-reflog \
        | grep commit \
        | cut -d ' ' -f3 \
        | xargs git log \
            --merges \
            --no-walk
```
----
Simplify your workflow, save time, and maximize productivity with these handy shortcuts. Happy coding!

[^images]: The repository shown is my [APDynamicGrid](https://github.com/antoniopantaleo/APDynamicGrid)
[^fuzzy]: [fzf](https://github.com/junegunn/fzf) is a powerful command-line finder
[^diffr]: I use [diffr](https://github.com/mookid/diffr), a diff highlighting tool