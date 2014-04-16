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
    if filereadable(fn . "/config/controllers.js") && fn != "."
      return s:BufInit(resolve(fn))
    endif
    let ofn = fn
    let fn = fnamemodify(ofn,':h')
    if fn == '/'
      let fn = ''
    endif
  endwhile
  call s:Leave()
  return 0
endfunction

function! s:rquote(str)
  if a:str =~ '^[A-Za-z0-9_/.:-]\+$'
    return a:str
  elseif &shell =~? 'cmd'
    return '"'.s:gsub(s:gsub(a:str, '"', '""'), '\%', '"%"').'"'
  else
    return shellescape(a:str)
  endif
endfunction

function! s:BufInit(path)
  let b:sails_root = a:path
endfunction

function! s:sub(str,pat,rep)
  return substitute(a:str,'\v\C'.a:pat,a:rep,'')
endfunction

let s:sid = s:sub(maparg("<SID>xx"),'xx$','')

function! s:error(str)
  echohl ErrorMsg
  echomsg a:str
  echohl None
  let v:errmsg = a:str
endfunction

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

function! s:itemList(path, A)
  let con = s:relglob(a:path,"**/*",".js")
  call map(con,'s:sub(v:val,"$","")')
  return s:autocamelize(con,a:A)
endfunction

function! s:modelList(A,L,P)
  return s:itemList("api/models/", a:A)
endfunction

function! s:configList(A,L,P)
  return s:itemList("config/", a:A)
endfunction

function! s:serviceList(A,L,P)
  return s:itemList("api/services/", a:A)
endfunction

function! s:adapterList(A,L,P)
  return s:itemList("api/adapters/", a:A)
endfunction

function! s:policyList(A,L,P)
  return s:itemList("api/policies/", a:A)
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

function! s:itemEdit(cmd, path, pattern)
  let item_name = matchstr(a:pattern, '[^#!]*')
  let file_candidates = [
        \b:sails_root . a:path . item_name . ".js",
        \b:sails_root . a:path . item_name,
        \b:sails_root . a:path . s:camelize(item_name) . ".js",
        \b:sails_root . a:path . s:camelize(item_name)
        \]
  let cmd = s:editcmdfor(a:cmd)
  for file_path in file_candidates
    if filereadable(file_path)
      return cmd . file_path
    endif
  endfor
  call s:error("Item not found")
endfunction

function! s:policyEdit(cmd,...)
  if !exists("a:1")
    call s:error("Policy name not specified")
    return
  endif
  return s:itemEdit(a:cmd, "/api/policies/", a:1)
endfunction

function! s:modelEdit(cmd,...)
  if !exists("a:1")
    call s:error("Model name not specified")
    return
  endif
  return s:itemEdit(a:cmd, "/api/models/", a:1)
endfunction

function! s:configEdit(cmd,...)
  if !exists("a:1")
    call s:error("Config name not specified")
    return
  endif
  return s:itemEdit(a:cmd, "/config/", a:1)
endfunction

function! s:serviceEdit(cmd,...)
  if !exists("a:1")
    call s:error("Service name not specified")
    return
  endif
  return s:itemEdit(a:cmd, "/api/services/", a:1)
endfunction

function! s:adapterEdit(cmd,...)
  if !exists("a:1")
    call s:error("Adapter name not specified")
    return
  endif
  return s:itemEdit(a:cmd, "/api/adapters/", a:1)
endfunction

function! s:viewEdit(cmd,...)
  if !exists("a:1")
    call s:error("View name not specified")
    return
  endif
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
  call s:error("View not found")
endfunction

function! s:controllerEdit(cmd,...)
  if !exists("a:1")
    call s:error("Controller name not specified")
    return
  endif
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
  call s:error("Controller not found")
endfunction

function s:Complete_generate(A, L, P)
  return s:completion_filter(['controller', 'model', 'view', 'adapter'], a:A)
endfunction

function! s:prepare_sails_command(cmd)
  return 'sails '.a:cmd
endfunction

function s:generator_command(bang,...)
  let cmd = join(map(copy(a:000),'s:rquote(v:val)'),' ')
  let &l:makeprg = s:prepare_sails_command(cmd)
  if a:bang
    make!
  else
    make
  endif
endfunction

function! s:addgenerators()
  command! -buffer -bang -bar -nargs=* -complete=customlist,s:Complete_generate Sgenerate :execute s:generator_command(<bang>0,'generate',<f-args>)
endfunction

function! s:SailsNavigation()
  call s:addfilecmds("controller")
  call s:addfilecmds("model")
  call s:addfilecmds("view")
  call s:addfilecmds("policy")
  call s:addfilecmds("config")
  call s:addfilecmds("service")
  call s:addfilecmds("adapter")
  call s:addgenerators()
endfunction

function! s:Leave()
  unlet! b:sails_root
endfunction

augroup sailsPlugin
  autocmd!
  autocmd User BufEnterSails call s:SailsNavigation()
  autocmd BufNewFile,BufRead * call s:Detect(expand("<afile>:p"))
  autocmd BufEnter * if exists("b:sails_root")|silent doau User BufEnterSails|endif
augroup END
