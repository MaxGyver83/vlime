function! VlimeCloseCurConnection()
    let conn = VlimeGetConnection()
    if type(conn) == v:t_none
        return
    endif
    call VlimeCloseConnection(conn)
    echom conn.cb_data['name'] . ' disconnected.'
endfunction

function! VlimeRenameCurConnection()
    let conn = VlimeGetConnection()
    if type(conn) == v:t_none
        return
    endif
    let new_name = input('New name: ', conn.cb_data['name'])
    call VlimeRenameConnection(conn, new_name)
endfunction

" VlimeConnectREPL(host, port[, remote_prefix[, name]])
function! VlimeConnectREPL(host, port, ...)
    let remote_prefix = vlime#GetNthVarArg(a:000, 0, '')
    let name = vlime#GetNthVarArg(a:000, 1, v:null)

    if type(name) == v:t_none
        let conn = VlimeNewConnection()
    else
        let conn = VlimeNewConnection(name)
    endif
    try
        call conn.Connect(a:host, a:port, remote_prefix)
    catch
        call VlimeCloseConnection(conn)
        call vlime#ui#ErrMsg(v:exception)
        return
    endtry
    call s:CleanUpNullBufConnections()

    let contribs = exists('g:vlime_contribs') ?
                \ g:vlime_contribs : [
                    \ 'SWANK-ASDF', 'SWANK-PACKAGE-FU',
                    \ 'SWANK-PRESENTATIONS', 'SWANK-FANCY-INSPECTOR',
                    \ 'SWANK-C-P-C', 'SWANK-ARGLISTS', 'SWANK-REPL',
                    \ 'SWANK-FUZZY']

    call vlime#ChainCallbacks(
                \ function(conn.ConnectionInfo, [v:true]),
                \ function('s:OnConnectionInfoComplete'),
                \ function(conn.SwankRequire, [contribs]),
                \ function('s:OnSwankRequireComplete'),
                \ function('vlime#contrib#CallInitializers', [conn]),
                \ function('s:OnCallInitializersComplete'))
endfunction

function! VlimeSelectCurConnection()
    let conn = VlimeSelectConnection(v:false)
    if type(conn) != v:t_none
        " XXX: Cleanup buffers & windows for the old connection?
        let b:vlime_conn = conn
    endif
endfunction

function! VlimeSendCurThingToREPL(thing)
    if a:thing == 'thing'
        let str = vlime#ui#CurExpr()
        if len(str) <= 0
            let str = vlime#ui#CurAtom()
        endif
    elseif a:thing == 'expr'
        let str = vlime#ui#CurExpr()
    elseif a:thing == 'atom'
        let str = vlime#ui#CurAtom()
    elseif a:thing == 'selection'
        let str = vlime#ui#CurSelection()
    endif

    if len(str) <= 0
        return
    endif

    let conn = VlimeGetConnection()
    if type(conn) == v:t_none
        return
    endif

    call conn.ui.OnWriteString(conn, "--\n", {'name': 'REPL-SEP', 'package': 'KEYWORD'})
    call conn.WithThread({'name': 'REPL-THREAD', 'package': 'KEYWORD'},
                \ function(conn.ListenerEval, [str]))
endfunction

function! VlimeCompileCurThing(thing)
    if a:thing == 'expr'
        let [str, s_pos, e_pos] = vlime#ui#CurExpr(v:true)
    elseif a:thing == 'selection'
        let [str, s_pos, e_pos] = vlime#ui#CurSelection(v:true)
    endif
    if len(str) <= 0
        return
    endif

    let conn = VlimeGetConnection()
    if type(conn) == v:t_none
        return
    endif

    call conn.ui.OnWriteString(conn, "--\n", {'name': 'REPL-SEP', 'package': 'KEYWORD'})
    let [str_line, str_col] = s_pos
    if exists('g:vlime_compiler_policy')
        let policy = g:vlime_compiler_policy
    else
        let policy = v:null
    endif
    call conn.CompileStringForEmacs(
                \ str, bufnr('%'),
                \ line2byte(str_line) + str_col - 1,
                \ expand('%:p'),
                \ policy,
                \ function('s:OnCompilationComplete'))
endfunction

function! VlimeInspectCurThing(thing)
    if a:thing == 'thing'
        let str = vlime#ui#CurExpr()
        if len(str) <= 0
            let str = vlime#ui#CurAtom()
        endif
    elseif a:thing == 'expr'
        let str = vlime#ui#CurExpr()
    elseif a:thing == 'atom'
        let str = vlime#ui#CurAtom()
    elseif a:thing == 'selection'
        let str = vlime#ui#CurSelection()
    endif

    if len(str) <= 0
        return
    endif

    let conn = VlimeGetConnection()
    if type(conn) == v:t_none
        return
    endif

    call conn.InitInspector(str,
                \ {c, r -> c.ui.OnInspect(c, r, v:null, v:null)})
endfunction

function! VlimeCompileCurFile()
    let fname = expand('%:p')
    if len(fname) <= 0
        return
    endif

    let conn = VlimeGetConnection()
    if type(conn) == v:t_none
        return
    endif

    if exists('g:vlime_compiler_policy')
        let policy = g:vlime_compiler_policy
    else
        let policy = v:null
    endif
    call conn.ui.OnWriteString(conn, "--\n", {'name': 'REPL-SEP', 'package': 'KEYWORD'})
    call conn.CompileFileForEmacs(fname, v:true, policy,
                \ function('s:OnCompilationComplete'))
endfunction

function! VlimeExpandCurMacro(expand_all)
    let expr = vlime#ui#CurExpr()
    if len(expr) <= 0
        return
    endif

    let conn = VlimeGetConnection()
    if type(conn) == v:t_none
        return
    endif

    if a:expand_all
        call conn.SwankMacroExpandAll(expr, function('s:ShowAsyncResult'))
    else
        call conn.SwankMacroExpandOne(expr, function('s:ShowAsyncResult'))
    endif
endfunction

function! VlimeDisassembleCurForm()
    let expr = vlime#ui#CurExpr()
    if len(expr) <= 0
        return
    endif

    let conn = VlimeGetConnection()
    if type(conn) == v:t_none
        return
    endif

    call conn.DisassembleForm(expr, function('s:ShowAsyncResult'))
endfunction

function! VlimeLoadCurFile()
    let fname = expand('%:p')
    if len(fname) > 0
        let conn = VlimeGetConnection()
        if type(conn) == v:t_none
            return
        endif

        call conn.LoadFile(fname, function('s:OnLoadFileComplete', [fname]))
    endif
endfunction

function! VlimeSetCurPackage()
    let conn = VlimeGetConnection()
    if type(conn) == v:t_none
        return
    endif

    let pkg = conn.GetCurrentPackage()
    let pkg = input('Set package: ', pkg[0])
    if len(pkg) <= 0
        call vlime#ui#ErrMsg('Canceled.')
        return
    endif
    call conn.SetPackage(pkg)
endfunction

function! VlimeSwankRequire(contribs)
    let conn = VlimeGetConnection()
    if type(conn) == v:t_none
        return
    endif
    call conn.SwankRequire(a:contribs, function('s:OnSwankRequireComplete'))
endfunction

function! VlimeCurOperatorArgList()
    let conn = VlimeGetConnection(v:true)
    if type(conn) == v:t_none
        return
    endif

    let [s_line, s_col] = searchpairpos('(', '', ')', 'bnW')
    if s_line <= 0 || s_col <= 0
        return
    endif

    let old_cur = getcurpos()
    try
        call setpos('.', [0, s_line, s_col, 0])
        let op = vlime#ui#CurOperator()
    finally
        call setpos('.', old_cur)
    endtry

    if len(op) > 0
        call conn.OperatorArgList(op, function('s:OnOperatorArgListComplete', [op]))
    endif
endfunction

function! VlimeDescribeCurSymbol(sym_type)
    if a:sym_type == 'operator'
        let sym = vlime#ui#CurOperator()
    elseif a:sym_type == 'atom'
        let sym = vlime#ui#CurAtom()
    endif
    if len(sym) > 0
        let conn = VlimeGetConnection()
        if type(conn) == v:t_none
            return
        endif
        call conn.DescribeSymbol(sym, function('s:ShowAsyncResult'))
    endif
endfunction

function! VlimeXRefCurSymbol(sym_type, ref_type)
    if a:sym_type == 'operator'
        let sym = vlime#ui#CurOperator()
    elseif a:sym_type == 'atom'
        let sym = vlime#ui#CurAtom()
    endif
    if len(sym) > 0
        let conn = VlimeGetConnection()
        if type(conn) == v:t_none
            return
        endif
        call conn.XRef(a:ref_type, sym, function('s:OnXRefComplete'))
    endif
endfunction

function! VlimeFindCurDefinition(sym_type)
    if a:sym_type == 'operator'
        let sym = vlime#ui#CurOperator()
    elseif a:sym_type == 'atom'
        let sym = vlime#ui#CurAtom()
    endif
    if len(sym) > 0
        let conn = VlimeGetConnection()
        if type(conn) == v:t_none
            return
        endif
        call conn.FindDefinitionsForEmacs(sym, function('s:OnXRefComplete'))
    endif
endfunction

function! VlimeAproposList()
    let conn = VlimeGetConnection()
    if type(conn) == v:t_none
        return
    endif
    call vlime#ui#InputFromMiniBuffer(
                \ conn, 'Apropos search:',
                \ v:null,
                \ 'call VlimeAproposListInputComplete() \| bunload!')
endfunction

function! VlimeAproposListInputComplete()
    let content = vlime#ui#CurBufferContent()
    call b:vlime_conn.AproposListForEmacs(
                \ content, v:false, v:false, v:null,
                \ function('s:OnAproposListComplete'))
endfunction

function! VlimeDocumentationSymbol(sym_type)
    if a:sym_type == 'operator'
        let sym = vlime#ui#CurOperator()
    elseif a:sym_type == 'atom'
        let sym = vlime#ui#CurAtom()
    endif
    if len(sym) > 0
        let conn = VlimeGetConnection()
        if type(conn) == v:t_none
            return
        endif
        call conn.DocumentationSymbol(sym, function('s:OnDocumentationSymbolComplete'))
    endif
endfunction

function! VlimeSetBreakpoint()
    let conn = VlimeGetConnection()
    if type(conn) == v:t_none
        return
    endif

    call vlime#ui#InputFromMiniBuffer(
                \ conn, 'Set breakpoint at function:',
                \ v:null,
                \ 'call VlimeSetBreakpointInputComplete() \| bunload!')
endfunction

function! VlimeSetBreakpointInputComplete()
    let content = vlime#ui#CurBufferContent()
    call b:vlime_conn.SLDBBreak(content, function('s:OnSLDBBreakComplete'))
endfunction

function! VlimeListThreads()
    let conn = VlimeGetConnection()
    if type(conn) == v:t_none
        return
    endif

    call conn.ListThreads(function('s:OnListThreadsComplete'))
endfunction

function! VlimeCompleteFunc(findstart, base)
    let start_col = s:CompleteFindStart()
    if a:findstart
        return start_col
    endif

    let conn = VlimeGetConnection()
    if type(conn) == v:t_none
        return -1
    endif

    if s:ConnHasContrib(conn, 'SWANK-FUZZY')
        call conn.FuzzyCompletions(a:base,
                    \ function('s:OnFuzzyCompletionsComplete', [start_col + 1]))
    else
        call conn.SimpleCompletions(a:base,
                    \ function('s:OnSimpleCompletionsComplete', [start_col + 1]))
    endif
    " Actual completions are found in s:OnFuzzyCompletionsComplete(...)
    " XXX: The refresh option doesn't work, why?
    return {'words': [], 'refresh': 'always'}
endfunction

function! VlimeKey(key)
    if tolower(a:key) == 'space'
        call VlimeCurOperatorArgList()
    elseif tolower(a:key) == 'cr'
        call VlimeCurOperatorArgList()
    elseif tolower(a:key) == 'tab'
        let line = getline('.')
        let spaces = vlime#ui#CalcLeadingSpaces(line, v:true)
        let col = virtcol('.')
        if col <= spaces + 1
            let indent = VlimeCalcCurIndent()
            if spaces < indent
                call vlime#ui#IndentCurLine(indent)
            else
                return "\<tab>"
            endif
        else
            return "\<c-x>\<c-o>"
        endif
    else
        throw 'VlimeKey: Unknown key: ' . a:key
    endif
    return ''
endfunction

function! VlimeCalcCurIndent()
    let line_no = line('.')

    let conn = VlimeGetConnection(v:true)
    if type(conn) == v:t_none
        return lispindent(line_no)
    endif

    let [s_line, s_col] = searchpairpos('(', '', ')', 'bnW')
    if s_line <= 0 || s_col <= 0
        return lispindent(line_no)
    endif

    let old_cur = getcurpos()
    try
        call setpos('.', [0, s_line, s_col, 0])
        let vs_col = virtcol('.')
        let s_op = vlime#ui#CurOperator()
    finally
        call setpos('.', old_cur)
    endtry

    let matches = matchlist(s_op, '\(\([^:|]\+\||[^|]\+|\):\{1,2}\)\?\([^:|]\+\||[^|]\+|\)$')
    if len(matches) == 0
        return lispindent(line_no)
    endif

    let op_pkg = toupper(s:NormalizeIdentifierForIndentInfo(matches[2]))
    let op = tolower(s:NormalizeIdentifierForIndentInfo(matches[3]))

    if len(op_pkg) == 0
        let op_pkg = conn.GetCurrentPackage()
        if type(op_pkg) == v:t_list
            let op_pkg = op_pkg[0]
        endif
    endif

    let indent_info = get(conn.cb_data, 'indent_info', {})
    if has_key(indent_info, op) && index(indent_info[op][1], op_pkg) >= 0
        return vs_col + 1
    else
        return lispindent(line_no)
    endif
endfunction

" VlimeSetup([force])
function! VlimeSetup(...)
    let force = vlime#GetNthVarArg(a:000, 0, v:false)

    if !force && exists('b:vlime_setup') && b:vlime_setup
        return
    endif
    let b:vlime_setup = v:true

    let [host, port] = exists('g:vlime_address') ?
                \ g:vlime_address : ['127.0.0.1', 7002]

    setlocal omnifunc=VlimeCompleteFunc
    setlocal indentexpr=VlimeCalcCurIndent()

    inoremap <buffer> <silent> <space> <space><c-r>=VlimeKey('space')<cr>
    inoremap <buffer> <silent> <cr> <cr><c-r>=VlimeKey("cr")<cr>
    inoremap <buffer> <silent> <tab> <c-r>=VlimeKey("tab")<cr>

    " Connection operations
    execute 'nnoremap <buffer> <silent> <LocalLeader>cc :call VlimeConnectREPL(' . string(host) . ', ' . port . ')<cr>'
    nnoremap <buffer> <silent> <LocalLeader>cs :call VlimeSelectCurConnection()<cr>
    nnoremap <buffer> <silent> <LocalLeader>cd :call VlimeCloseCurConnection()<cr>
    nnoremap <buffer> <silent> <LocalLeader>cr :call VlimeRenameCurConnection()<cr>

    " Sending stuff to the REPL
    nnoremap <buffer> <silent> <LocalLeader>ss :call VlimeSendCurThingToREPL('thing')<cr>
    nnoremap <buffer> <silent> <LocalLeader>se :call VlimeSendCurThingToREPL('expr')<cr>
    nnoremap <buffer> <silent> <LocalLeader>sa :call VlimeSendCurThingToREPL('atom')<cr>
    vnoremap <buffer> <silent> <LocalLeader>s :<c-u>call VlimeSendCurThingToREPL('selection')<cr>

    " Expanding macros
    nnoremap <buffer> <silent> <LocalLeader>m1 :call VlimeExpandCurMacro(v:false)<cr>
    nnoremap <buffer> <silent> <LocalLeader>ma :call VlimeExpandCurMacro(v:true)<cr>

    " Compilation operations
    nnoremap <buffer> <silent> <LocalLeader>oe :call VlimeCompileCurThing('expr')<cr>
    nnoremap <buffer> <silent> <LocalLeader>of :call VlimeCompileCurFile()<cr>
    vnoremap <buffer> <silent> <LocalLeader>o :<c-u>call VlimeCompileCurThing('selection')<cr>

    " Cross references (XRef)
    nnoremap <buffer> <silent> <LocalLeader>xc :call VlimeXRefCurSymbol('atom', 'CALLS')<cr>
    nnoremap <buffer> <silent> <LocalLeader>xC :call VlimeXRefCurSymbol('atom', 'CALLS-WHO')<cr>
    nnoremap <buffer> <silent> <LocalLeader>xr :call VlimeXRefCurSymbol('atom', 'REFERENCES')<cr>
    nnoremap <buffer> <silent> <LocalLeader>xb :call VlimeXRefCurSymbol('atom', 'BINDS')<cr>
    nnoremap <buffer> <silent> <LocalLeader>xs :call VlimeXRefCurSymbol('atom', 'SETS')<cr>
    nnoremap <buffer> <silent> <LocalLeader>xe :call VlimeXRefCurSymbol('atom', 'MACROEXPANDS')<cr>
    nnoremap <buffer> <silent> <LocalLeader>xm :call VlimeXRefCurSymbol('atom', 'SPECIALIZES')<cr>
    nnoremap <buffer> <silent> <LocalLeader>xd :call VlimeFindCurDefinition('atom')<cr>

    " Describing things
    nnoremap <buffer> <silent> <LocalLeader>do :call VlimeDescribeCurSymbol('operator')<cr>
    nnoremap <buffer> <silent> <LocalLeader>da :call VlimeDescribeCurSymbol('atom')<cr>
    nnoremap <buffer> <silent> <LocalLeader>ds :call VlimeAproposList()<cr>
    nnoremap <buffer> <silent> <LocalLeader>ddo :call VlimeDocumentationSymbol('operator')<cr>
    nnoremap <buffer> <silent> <LocalLeader>dda :call VlimeDocumentationSymbol('atom')<cr>
    nnoremap <buffer> <silent> <LocalLeader>dr :call VlimeCurOperatorArgList()<cr>

    " Inspection
    nnoremap <buffer> <silent> <LocalLeader>II :call VlimeInspectCurThing('thing')<cr>
    nnoremap <buffer> <silent> <LocalLeader>Ii :call VlimeInspectCurThing('thing')<cr>
    nnoremap <buffer> <silent> <LocalLeader>IE :call VlimeInspectCurThing('expr')<cr>
    nnoremap <buffer> <silent> <LocalLeader>Ie :call VlimeInspectCurThing('expr')<cr>
    nnoremap <buffer> <silent> <LocalLeader>IA :call VlimeInspectCurThing('atom')<cr>
    nnoremap <buffer> <silent> <LocalLeader>Ia :call VlimeInspectCurThing('atom')<cr>
    vnoremap <buffer> <silent> <LocalLeader>I :<c-u>call VlimeInspectCurThing('selection')<cr>

    " Other stuff
    nnoremap <buffer> <silent> <LocalLeader>i :call VlimeInteractionMode()<cr>
    nnoremap <buffer> <silent> <LocalLeader>l :call VlimeLoadCurFile()<cr>
    nnoremap <buffer> <silent> <LocalLeader>a :call VlimeDisassembleCurForm()<cr>
    nnoremap <buffer> <silent> <LocalLeader>p :call VlimeSetCurPackage()<cr>
    nnoremap <buffer> <silent> <LocalLeader>b :call VlimeSetBreakpoint()<cr>
    nnoremap <buffer> <silent> <LocalLeader>t :call VlimeListThreads()<cr>
endfunction

function! VlimeInteractionMode()
    if getbufvar(bufnr('%'), 'vlime_interaction_mode', v:false)
        let b:vlime_interaction_mode = v:false
        nnoremap <buffer> <cr> <cr>
        vnoremap <buffer> <cr> <cr>
        echom 'Interaction mode disabled.'
    else
        let b:vlime_interaction_mode = v:true
        nnoremap <buffer> <silent> <cr> :call VlimeSendCurThingToREPL('thing')<cr>
        vnoremap <buffer> <silent> <cr> :<c-u>call VlimeSendCurThingToREPL('selection')<cr>
        echom 'Interaction mode enabled.'
    endif
endfunction

function! s:NormalizeIdentifierForIndentInfo(ident)
    let ident_len = len(a:ident)
    if ident_len >= 2 && a:ident[0] == '|' && a:ident[ident_len-1] == '|'
        return strpart(a:ident, 1, ident_len - 2)
    else
        return a:ident
    endif
endfunction

function! s:CompleteFindStart()
    let col = col('.') - 1
    let line = getline('.')
    while col > 0 && match(line[col-1], '\_s\|[()#;"'']') < 0
        let col -= 1
    endwhile
    return col
endfunction

function! s:ConnHasContrib(conn, contrib)
    return has_key(a:conn.cb_data, 'contribs') &&
                \ index(a:conn.cb_data['contribs'], a:contrib) >= 0
endfunction

function! s:OnCallInitializersComplete(conn)
    echom a:conn.cb_data['name'] . ' established.'
endfunction

function! s:OnSwankRequireComplete(conn, result)
    let a:conn.cb_data['contribs'] = a:result
endfunction

function! s:OnConnectionInfoComplete(conn, result)
    let a:conn.cb_data['version'] = a:result['VERSION']
    let a:conn.cb_data['pid'] = a:result['PID']
endfunction

function! s:OnFuzzyCompletionsComplete(col, conn, result)
    let comps = a:result[0]
    if type(comps) == v:t_none
        let comps = []
    endif
    let r_comps = []
    for c in comps
        let cobj = {'word': c[0],'menu': c[3]}
        call add(r_comps, cobj)
    endfor
    call complete(a:col, r_comps)
endfunction

function! s:OnSimpleCompletionsComplete(col, conn, result)
    let comps = a:result[0]
    if type(comps) == v:t_none
        let comps = []
    endif
    call complete(a:col, comps)
endfunction

function! s:OnOperatorArgListComplete(sym, conn, result)
    if type(a:result) == v:t_none
        return
    endif
    let old_pos = getcurpos()
    try
        call vlime#ui#ShowPreview(a:conn, a:result, v:false, 2)
    finally
        call setpos('.', old_pos)
    endtry
endfunction

function! s:OnLoadFileComplete(fname, conn, result)
    echom 'Loaded: ' . a:fname
endfunction

function! s:OnXRefComplete(conn, result)
    if type(a:conn.ui) != v:t_none
        call a:conn.ui.OnXRef(a:conn, a:result)
    endif
endfunction

function! s:OnAproposListComplete(conn, result)
    if type(a:result) == v:t_none
        call vlime#ui#ShowPreview(a:conn, 'No result found.', v:false, 12)
    else
        let content = ''
        for item in a:result
            let item_dict = vlime#PListToDict(item)
            let content .= item_dict['DESIGNATOR']
            let flags = map(filter(keys(item_dict), {f -> f != 'DESIGNATOR'}), {i, f -> tolower(f)})
            if len(flags) > 0
                let content .= ' ('
                let content .= join(flags, ', ')
                let content .= ')'
            endif
            let content .= "\n"
        endfor
        call vlime#ui#ShowPreview(a:conn, content, v:false, 12)
    endif
endfunction

function! s:OnDocumentationSymbolComplete(conn, result)
    call vlime#ui#ShowPreview(a:conn, a:result, v:false, 12)
endfunction

function! s:OnSLDBBreakComplete(conn, result)
    echom 'Breakpoint set.'
endfunction

function! s:OnCompilationComplete(conn, result)
    let [_msg_type, notes, successp, duration, loadp, faslfile] = a:result
    if successp
        echom 'Compilation finished in ' . string(duration) . ' second(s)'
        if loadp && type(faslfile) != v:null
            call a:conn.LoadFile(faslfile, function('s:OnLoadFileComplete', [faslfile]))
        endif
    else
        call vlime#ui#ErrMsg('Compilation failed.')
    endif

    if type(a:conn.ui) != v:t_none
        call a:conn.ui.OnCompilerNotes(a:conn, notes)
    endif
endfunction

function! s:OnListThreadsComplete(conn, result)
    if type(a:conn.ui) != v:t_none
        call a:conn.ui.OnThreads(a:conn, a:result)
    endif
endfunction

function! s:ShowAsyncResult(conn, result)
    let old_pos = getcurpos()
    try
        call vlime#ui#ShowPreview(a:conn, a:result, v:false, 12)
    finally
        call setpos('.', old_pos)
    endtry
endfunction

function! s:CleanUpNullBufConnections()
    let old_buf = bufnr('%')
    try
        bufdo! if exists('b:vlime_conn') && type(b:vlime_conn) == v:t_none
                    \ | unlet b:vlime_conn | endif
    finally
        execute 'hide buffer ' . old_buf
    endtry
endfunction
