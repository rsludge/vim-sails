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

augroup sailsPlugin
  autocmd!
  autocmd BufNewFile,BufRead * call s:Detect(expand("<afile>:p"))
  autocmd BufEnter * if exists("b:sails_root")|silent doau User BufEnterSails|endif
augroup END
