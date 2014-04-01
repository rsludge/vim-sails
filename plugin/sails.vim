function! s:Detect(filename)
  if exists('b:sails_root')
    return s:BufInit(b:sails_root)
  endif
  let fn = substitute(fnamemodify(a:filename,":p"),'\c^file://','','')
  let sep = matchstr(fn,'^[^\\/]\{3,\}\zs[\\/]')
  if sep != ""
    let fn = getcwd().sep.fn
  endif
  if isdirectory(fn)
    let fn = fnamemodify(fn,':s?[\/]$??')
  else
    let fn = fnamemodify(fn,':s?\(.*\)[\/][^\/]*$?\1?')
  endif
  let ofn = ""
  while fn != ofn
    if filereadable(fn . "/config/controllers.js")
      return s:BufInit(resolve(fn))
    endif
    let ofn = fn
    let fn = fnamemodify(ofn,':h')
    if fn == '/'
      let fn = ''
    endif
  endwhile
  return 0
endfunction

function! s:BufInit(path)
  let b:sails_root = a:path
endfunction

function! s:sub(str,pat,rep)
  return substitute(a:str,'\v\C'.a:pat,a:rep,'')
endfunction

let s:sid = s:sub(maparg("<SID>xx"),'xx$','')

function! s:addfilecmds(type)
  let l = s:sub(a:type,'^.','\l&')
  for prefix in ['E', 'S', 'V', 'T', 'D', 'R', 'RE', 'RS', 'RV', 'RT', 'RD']
    exe "command! -buffer -bar ".(prefix =~# 'D' ? '-range=0 ' : '')."-nargs=*"." ".prefix.l." :execute s:".l.'Edit("'.(prefix =~# 'D' ? '<line1>' : '').s:sub(prefix, '^R', '').'<bang>",<f-args>)'
  endfor
endfunction

function! s:controllerEdit(cmd,...)
  let controller_name = matchstr(a:1, '[^#!]*')
  let file_path = b:sails_root . "/api/controllers/" . controller_name . "Controller.js"
  execute 'edit '. file_path
endfunction

function! s:SailsNavigation()
  call s:addfilecmds("controller")
endfunction

augroup sailsPlugin
  autocmd!
  autocmd User BufEnterSails call s:SailsNavigation()
  autocmd BufNewFile,BufRead * call s:Detect(expand("<afile>:p"))
  autocmd BufEnter * if exists("b:sails_root")|silent doau User BufEnterSails|endif
augroup END
