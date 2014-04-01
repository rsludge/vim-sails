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

function! s:completion_filter(results,A)
  let results = sort(type(a:results) == type("") ? split(a:results,"\n") : copy(a:results))
  call filter(results,'v:val !~# "\\~$"')
  if a:A =~# '\*'
    let regex = s:gsub(a:A,'\*','.*')
    return filter(copy(results),'v:val =~# "^".regex')
  endif
  let filtered = filter(copy(results),'s:startswith(v:val,a:A)')
  if !empty(filtered) | return filtered | endif
  let filtered = filter(copy(results),'s:startswith(v:val,s:camelize(a:A))')
  return filtered
endfunction

function! s:startswith(string,prefix)
  return strpart(a:string, 0, strlen(a:prefix)) ==# a:prefix
endfunction

function! s:autocamelize(files,test)
  if a:test =~# '^\u'
    return s:completion_filter(map(copy(a:files),'rails#camelize(v:val)'),a:test)
  else
    return s:completion_filter(a:files,a:test)
  endif
endfunction

function! s:controllerList(A,L,P)
  let con = s:relglob("api/controllers/","**/*",".js")
  call map(con,'s:sub(v:val,"Controller$","")')
  return s:autocamelize(con,a:A)
endfunction

function! s:addfilecmds(type)
  let l = s:sub(a:type,'^.','\l&')
  let cplt = " -complete=customlist,s:".s:sid.l."List"
  for prefix in ['E', 'S', 'V', 'T', 'D', 'R', 'RE', 'RS', 'RV', 'RT', 'RD']
    exe "command! -buffer -bar ".(prefix =~# 'D' ? '-range=0 ' : '')."-nargs=*".cplt." ".prefix.l." :execute s:".l.'Edit("'.(prefix =~# 'D' ? '<line1>' : '').s:sub(prefix, '^R', '').'<bang>",<f-args>)'
  endfor
endfunction

function! s:relglob(path,glob,...)
  if exists("+shellslash") && ! &shellslash
    let old_ss = &shellslash
    let &shellslash = 1
  endif
  let path = a:path
  if path !~ '^/' && path !~ '^\w:'
    let path = b:sails_root . '/' . path
  endif
  let suffix = a:0 ? a:1 : ''
  let full_paths = split(glob(path.a:glob.suffix),"\n")
  let relative_paths = []
  for entry in full_paths
    if suffix == '' && isdirectory(entry) && entry !~ '/$'
      let entry .= '/'
    endif
    let relative_paths += [entry[strlen(path) : -strlen(suffix)-1]]
  endfor
  if exists("old_ss")
    let &shellslash = old_ss
  endif
  return relative_paths
endfunction

function! s:camelize(str)
  let str = s:gsub(a:str,'/(.=)','::\u\1')
  let str = s:gsub(str,'%([_-]|<)(.)','\u\1')
  return str
endfunction

function! s:gsub(str,pat,rep)
  return substitute(a:str,'\v\C'.a:pat,a:rep,'g')
endfunction

function! s:controllerEdit(cmd,...)
  let controller_name = matchstr(a:1, '[^#!]*')
  let file_candidates = [
        \b:sails_root . "/api/controllers/" . controller_name . "Controller.js",
        \b:sails_root . "/api/controllers/" . controller_name . ".js",
        \b:sails_root . "/api/controllers/" . controller_name,
        \b:sails_root . "/api/controllers/" . s:camelize(controller_name) . "Controller.js",
        \b:sails_root . "/api/controllers/" . s:camelize(controller_name) . ".js",
        \b:sails_root . "/api/controllers/" . s:camelize(controller_name)
        \]
  for file_path in file_candidates
    if filereadable(file_path)
      execute 'edit '. file_path
    endif
  endfor
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
