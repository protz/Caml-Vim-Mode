let s:camlIsSetUp = 0

function CleanCaml ()
  
  " Suppression d'éventuelles fenêtres d'édition déjà actives
  let s:n = bufwinnr("/tmp/.jpein")
  while s:n >= 0
    exe s:n . "wincmd w"
    q!
    let s:n = bufwinnr("/tmp/.jpein")
  endwhile

  " Suppression d'éventuelles fenêtres de sortie déjà actives
  let s:n = bufwinnr("/tmp/.jpeout")
  while s:n >= 0
    exe s:n . "wincmd w"
    q!
    let s:n = bufwinnr("/tmp/.jpeout")
  endwhile

  " FIXME : tue d'autres processus qui auraient pu servir...
  let s:tt = system("killall ocaml")
  let s:tt = system("killall tail")

  " Nettoyage de fichiers usagés
  " TODO : faire en nettoyage en sortie et identifier les fichiers avec le pid
  " du processus caml par exemple
  let s:tt = system("rm -f /tmp/.jppipe /tmp/.jpout /tmp/.jpin")

endfunction

function SetUpCaml ()

  " Création des différents fichiers nécessaires
  let s:tt = system("touch /tmp/.jpin")
  let s:tt = system("touch /tmp/.jpout")
  let s:tt = system("mknod /tmp/.jppipe p")

  " On lance l'interpréteur
  let s:tt = system("tail -f /tmp/.jppipe | ocaml > /tmp/.jpout 2>/tmp/.jperr &")

  " Et on attend que la sortie soit arrivée
  let s:size = getfsize("/tmp/.jpout")
  while s:size == 0
    let s:tt = system("sleep .01")
    let s:size = getfsize("/tmp/.jpout")
  endwhile

  " On a encore rien vu de la sortie (dernière position connue : (1,1))
  let s:oline = 1
  let s:ocol = 1

  " On identifie nos buffers grâce à leurs numéros
  let s:inBufNr = bufnr("%")
  new
  let s:outBufNr = bufnr("%")

  let s:camlIsSetUp = 1

endfunction

function UpdateOutput ()

  " But du jeu : ouvrir un buffer invisible (éventuellement avant) puis copier
  " de la dernière position (oline, ocol) jusqu'à la fin et mémoriser la
  " nouvelle position une fois la fin atteinte. Ne pas oublier les 0 et les $
  
  " On se met à la dernière position connue
  new /tmp/.jpout
  exe "normal ".s:oline."gg"
  normal 0
  if s:ocol > 1
    exe "normal ".(s:ocol-1)."l"
  endif

  " On remplit le buffer j
  let @j = ""
  let s:tcol = col(".")
  normal l
  if col(".") > s:tcol
    normal "Jy$
  endif
  let s:tline = line(".")
  normal j
  if line(".") > s:tline
    normal 0"JyG
  endif

  " On va à la fin et on mémorise la nouvelle position
  normal G$
  let s:ocol = col(".")
  let s:oline = line(".")

  bdelete!

  " On affiche
  exe s:outBufNr."wincmd w" 
  normal G$
  normal p

  " Série d'élimination de codes spéciaux
  " La partie qui est soulignée entre 4 et 24 devient entre commentaires
  normal mj
  :.,$s/\[4m\(.*\)\[24m/(*\1*)/egi
  " Le message d'erreur (ligne commençant par 24) pareil
  normal 'j
  :.,$s/\[24m\(.*\)$/(*\1*)/egi
  " Suppression de codes restants
  normal 'j
  silent :.,$s/\[\([0-9]\{1,2}m\|A\)//egi

  " normal ggG$

  " On repart sur l'éditeur
  exe s:inBufNr."wincmd w"

endfunction

function OpenCaml ()

  call CleanCaml()
  call SetUpCaml()
  call UpdateOutput()

  " Mise en forme du début de la sortie
  exe s:outBufNr."wincmd w"
  normal ggdd0i(*
  normal $a       *)
  normal G$
  set ft=omlet
    set foldnestmax=0
  exe s:inBufNr."wincmd w"
  set ft=omlet

endfunction

:map <F2> :call OpenCaml()<CR>

function FlushCaml ()

  exe s:inBufNr."wincmd w"
  let @j = ""
  " On va à la fin de la commande sur laquelle se trouve le curseur
  let s:tt = search(";;","W")
  let s:trouve = search(";;","Wbs")
  if s:trouve > 0
    " On se met sur le second ; de la commande précédente
    normal l
    let s:tcol = col(".")
    normal l
    if col(".") == s:tcol
      " S'il n'y a plus rien d'autre sur la ligne, le reste est à la ligne
      " suivante
      let s:tline = line(".")
      normal j0
      " On était à la fin du document
      if line(".") == s:tline
        let s:tt = search(";;","Wb")
        call FlushCaml ()
        return
      endif
    endif
  else
    " On n'a pas de ;; avant nous : on doit donc tout prendre depuis le
    " début
    normal gg0
  endif

  " On copie tout jusqu'à la fin de la commande
  silent exe "normal \"Jy/;;\<CR>"
  " Avec les deux points
  silent exe "normal /;;\<CR>"
  silent exe "normal \"Jy2l"

  " On décale l'appel à WriteToCaml au moment où on est sûr de pas avoir lu
  " deux fois la même commande

  " On tente d'aller de l'avant
  let s:tcol = col(".")
  let s:tline = line(".")

  " On arrête si on est revenu à la case départ
  if (s:tcol == s:pcol) && (s:tline == s:pline)
    " On a lu la dernière commande une fois de trop
    let @j=""
    return
  else
    let s:pcol = s:tcol
    let s:pline = s:tline
  endif

  " Si c'est bon, on flushe
  call WriteToCaml()

    " Pas besoin d'aller plus loin, à l'utilisateur de demander

  normal l
  if col(".") > s:tcol
    " On a réussi à aller à droite : il y a encore quelque chose
    " call FlushCaml()
    return
  endif

  normal j
  if line(".") > s:tline
    " On a réussi à aller en bas : il y a encore quelque chose
    " call FlushCaml()
    return
  endif

endfunction

function FlushCaml2 ()
    if !s:camlIsSetUp
        return
    endif
  let s:pcol = 0
  let s:pline = 0
  call FlushCaml()
endfunction

function WriteToCaml ()

  " On affiche dans la fenêtre de sortie ce qu'on vient de taper
  exe s:outBufNr."wincmd w"
  normal G$
  exe "normal \"jp"

  " On l'envoie à l'interpréteur
  new /tmp/.jpin
  normal gg0
  normal dG
  exe "normal \"jp"
  wq
  
  " Et quand ce dernier a répondu 
  let s:osize = getfsize("/tmp/.jpout")
  let s:tt = system("cat /tmp/.jpin > /tmp/.jppipe")
  let s:size = getfsize("/tmp/.jpout")
  while s:size == s:osize
    let s:tt = system("sleep .01")
    let s:size = getfsize("/tmp/.jpout")
  endwhile

  " On affiche sa réponse :)
  call UpdateOutput()

endfunction

:map <F3> :call FlushCaml2()<CR>
:imap <F3> <Esc>:call FlushCaml2()<CR>

