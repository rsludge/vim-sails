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

function! s:modelList(A,L,P)
  let con = s:relglob("api/models/","**/*",".js")
  call map(con,'s:sub(v:val,"$","")')
  return s:autocamelize(con,a:A)
endfunction

function! s:configList(A,L,P)
  let con = s:relglob("config/","**/*",".js")
  call map(con,'s:sub(v:val,"$","")')
  return s:autocamelize(con,a:A)
endfunction

function! s:serviceList(A,L,P)
  let con = s:relglob("api/services/","**/*",".js")
  call map(con,'s:sub(v:val,"$","")')
  return s:autocamelize(con,a:A)
endfunction

function! s:policyList(A,L,P)
  let con = s:relglob("api/policies/","**/*",".js")
  call map(con,'s:sub(v:val,"$","")')
  return s:autocamelize(con,a:A)
endfunction

function! s:viewList(A,L,P)
  let con = s:relglob("views/","**/*",".ejs")
  call map(con,'s:sub(v:val,"$","")')
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

function! s:findcmdfor(cmd)
  let bang = ''
  if a:cmd =~ '\!$'
    let bang = '!'
    let cmd = s:sub(a:cmd,'\!$','')
  else
    let cmd = a:cmd
  endif
  if cmd =~ '^\d'
    let num = matchstr(cmd,'^\d\+')
    let cmd = s:sub(cmd,'^\d+','')
  else
    let num = ''
  endif
  if cmd == '' || cmd == 'E' || cmd == 'F'
    return num.'find'.bang
  elseif cmd == 'S'
    return num.'sfind'.bang
  elseif cmd == 'V'
    return 'vert '.num.'sfind'.bang
  elseif cmd == 'T'
    return num.'tabfind'.bang
  elseif cmd == 'D'
    return num.'read'.bang
  else
    return num.cmd.bang
  endif
endfunction

function! s:editcmdfor(cmd)
  let cmd = s:findcmdfor(a:cmd)
  let cmd = s:sub(cmd,'<sfind>','split')
  let cmd = s:sub(cmd,'find>','edit')
  return cmd
endfunction

function! s:policyEdit(cmd,...)
  let policy_name = matchstr(a:1, '[^#!]*')
  let file_candidates = [
        \b:sails_root . "/api/policies/" . policy_name . ".js",
        \b:sails_root . "/api/policies/" . policy_name,
        \b:sails_root . "/api/policies/" . s:camelize(policy_name) . ".js",
        \b:sails_root . "/api/policies/" . s:camelize(policy_name)
        \]
  let cmd = s:editcmdfor(a:cmd)
  for file_path in file_candidates
    if filereadable(file_path)
      return cmd . file_path
    endif
  endfor
endfunction

function! s:modelEdit(cmd,...)
  let model_name = matchstr(a:1, '[^#!]*')
  let file_candidates = [
        \b:sails_root . "/api/models/" . model_name . ".js",
        \b:sails_root . "/api/models/" . model_name,
        \b:sails_root . "/api/models/" . s:camelize(model_name) . ".js",
        \b:sails_root . "/api/models/" . s:camelize(model_name)
        \]
  let cmd = s:editcmdfor(a:cmd)
  for file_path in file_candidates
    if filereadable(file_path)
      return cmd . file_path
    endif
  endfor
endfunction

function! s:configEdit(cmd,...)
  let config_name = matchstr(a:1, '[^#!]*')
  let file_candidates = [
        \b:sails_root . "/config/" . config_name . ".js",
        \b:sails_root . "/config/" . config_name,
        \b:sails_root . "/config/" . s:camelize(config_name) . ".js",
        \b:sails_root . "/config/" . s:camelize(config_name)
        \]
  let cmd = s:editcmdfor(a:cmd)
  for file_path in file_candidates
    if filereadable(file_path)
      return cmd . file_path
    endif
  endfor
endfunction

function! s:serviceEdit(cmd,...)
  let service_name = matchstr(a:1, '[^#!]*')
  let file_candidates = [
        \b:sails_root . "/api/services/" . service_name . ".js",
        \b:sails_root . "/api/services/" . service_name,
        \b:sails_root . "/api/services/" . s:camelize(service_name) . ".js",
        \b:sails_root . "/api/services/" . s:camelize(service_name)
        \]
  let cmd = s:editcmdfor(a:cmd)
  for file_path in file_candidates
    if filereadable(file_path)
      return cmd . file_path
    endif
  endfor
endfunction

function! s:viewEdit(cmd,...)
  let view_name = matchstr(a:1, '[^#!]*')
  let file_candidates = [
        \b:sails_root . "/views/" . view_name . ".ejs",
        \b:sails_root . "/views/" . view_name,
        \b:sails_root . "/views/" . s:camelize(view_name) . ".ejs",
        \b:sails_root . "/views/" . s:camelize(view_name)
        \]
  let cmd = s:editcmdfor(a:cmd)
  for file_path in file_candidates
    if filereadable(file_path)
      return cmd . file_path
    endif
  endfor
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
  let cmd = s:editcmdfor(a:cmd)
  for file_path in file_candidates
    if filereadable(file_path)
      return cmd . file_path
    endif
  endfor
endfunction

function! s:SailsNavigation()
  call s:addfilecmds("controller")
  call s:addfilecmds("model")
  call s:addfilecmds("view")
  call s:addfilecmds("policy")
  call s:addfilecmds("config")
  call s:addfilecmds("service")
endfunction

augroup sailsPlugin
  autocmd!
  autocmd User BufEnterSails call s:SailsNavigation()
  autocmd BufNewFile,BufRead * call s:Detect(expand("<afile>:p"))
  autocmd BufEnter * if exists("b:sails_root")|silent doau User BufEnterSails|endif
augroup END
