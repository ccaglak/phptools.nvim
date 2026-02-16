[](https://neovim.io/doc/user/deprecated.html#deprecated)

# Deprecated

_Nvim  `:help`  pages,  [generated](https://github.com/neovim/neovim/blob/master/src/gen/gen_help_html.lua)  from  [source](https://github.com/neovim/neovim/blob/master/runtime/doc/deprecated.txt)  using the  [tree-sitter-vimdoc](https://github.com/neovim/tree-sitter-vimdoc)  parser._

----------

Nvim

The items listed below are deprecated: they will be removed in the future. They should not be used in new scripts, and old scripts should be updated.

## **Deprecated**features

### DEPRECATED IN 0.12[deprecated-0.12](https://neovim.io/doc/user/deprecated.html#deprecated-0.12)

### API

todo

### DIAGNOSTICS

"float" in  [vim.diagnostic.JumpOpts](https://neovim.io/doc/user/diagnostic.html#vim.diagnostic.JumpOpts). Use "on_jump" instead.

"float" in  [vim.diagnostic.Opts.Jump](https://neovim.io/doc/user/diagnostic.html#vim.diagnostic.Opts.Jump). Use "on_jump" instead.

### HIGHLIGHTS

[:ownsyntax](https://neovim.io/doc/user/deprecated.html#%3Aownsyntax)  [w:current_syntax](https://neovim.io/doc/user/deprecated.html#w%3Acurrent_syntax)  Use  ['winhighlight'](https://neovim.io/doc/user/options.html#'winhighlight')  instead.

### LSP

[vim.lsp.client_is_stopped()](https://neovim.io/doc/user/deprecated.html#vim.lsp.client_is_stopped())  Use  [vim.lsp.get_client_by_id()](https://neovim.io/doc/user/lsp.html#vim.lsp.get_client_by_id())  instead.

[vim.lsp.util.stylize_markdown()](https://neovim.io/doc/user/deprecated.html#vim.lsp.util.stylize_markdown())  Use  [vim.treesitter.start()](https://neovim.io/doc/user/treesitter.html#vim.treesitter.start())  with  `vim.wo.conceallevel = 2`.

[vim.lsp.log.should_log()](https://neovim.io/doc/user/deprecated.html#vim.lsp.log.should_log())  Use  [vim.lsp.log.set_format_func()](https://neovim.io/doc/user/lsp.html#vim.lsp.log.set_format_func())  instead and return  `nil`  to omit entries from the logfile.

[vim.lsp.semantic_tokens.start()](https://neovim.io/doc/user/deprecated.html#vim.lsp.semantic_tokens.start())  Use  `vim.lsp.semantic_tokens.enable(true)`  instead

[vim.lsp.semantic_tokens.stop()](https://neovim.io/doc/user/deprecated.html#vim.lsp.semantic_tokens.stop())  Use  `vim.lsp.semantic_tokens.enable(false)`  instead

[vim.lsp.set_log_level()](https://neovim.io/doc/user/deprecated.html#vim.lsp.set_log_level())  Use  `vim.lsp.log.set_level()`  instead

[vim.lsp.get_log_path()](https://neovim.io/doc/user/deprecated.html#vim.lsp.get_log_path())  Use  `vim.lsp.log.get_filename()`  instead

[vim.lsp.get_buffers_by_client_id()](https://neovim.io/doc/user/deprecated.html#vim.lsp.get_buffers_by_client_id())  Use  `vim.lsp.get_client_by_id(id).attached_buffers`  instead

[vim.lsp.stop_client()](https://neovim.io/doc/user/deprecated.html#vim.lsp.stop_client())  Use  [Client:stop()](https://neovim.io/doc/user/lsp.html#Client%3Astop())  instead

### LUA

[vim.diff()](https://neovim.io/doc/user/deprecated.html#vim.diff())  Renamed to  [vim.text.diff()](https://neovim.io/doc/user/lua.html#vim.text.diff())

### VIMSCRIPT

todo

### DEPRECATED IN 0.11[deprecated-0.11](https://neovim.io/doc/user/deprecated.html#deprecated-0.11)

### API

nvim_notify() Use  [nvim_echo()](https://neovim.io/doc/user/api.html#nvim_echo())  or  `nvim_exec_lua("vim.notify(...)", ...)`  instead.

nvim_subscribe() Plugins must maintain their own "multicast" channels list.

nvim_unsubscribe() Plugins must maintain their own "multicast" channels list.

nvim_out_write() Use  [nvim_echo()](https://neovim.io/doc/user/api.html#nvim_echo()).

nvim_err_write() Use  [nvim_echo()](https://neovim.io/doc/user/api.html#nvim_echo())  with  `{err=true}`.

nvim_err_writeln() Use  [nvim_echo()](https://neovim.io/doc/user/api.html#nvim_echo())  with  `{err=true}`.

nvim_buf_add_highlight() Use  [vim.hl.range()](https://neovim.io/doc/user/lua.html#vim.hl.range())  or  [nvim_buf_set_extmark()](https://neovim.io/doc/user/api.html#nvim_buf_set_extmark())

### DIAGNOSTICS

[vim.diagnostic.goto_next()](https://neovim.io/doc/user/deprecated.html#vim.diagnostic.goto_next())  Use  [vim.diagnostic.jump()](https://neovim.io/doc/user/diagnostic.html#vim.diagnostic.jump())  with  `{count=1, float=true}`  instead.

[vim.diagnostic.goto_prev()](https://neovim.io/doc/user/deprecated.html#vim.diagnostic.goto_prev())  Use  [vim.diagnostic.jump()](https://neovim.io/doc/user/diagnostic.html#vim.diagnostic.jump())  with  `{count=-1, float=true}`  instead.

[vim.diagnostic.get_next_pos()](https://neovim.io/doc/user/deprecated.html#vim.diagnostic.get_next_pos())  Use the "lnum" and "col" fields from the return value of  [vim.diagnostic.get_next()](https://neovim.io/doc/user/diagnostic.html#vim.diagnostic.get_next())  instead.

[vim.diagnostic.get_prev_pos()](https://neovim.io/doc/user/deprecated.html#vim.diagnostic.get_prev_pos())  Use the "lnum" and "col" fields from the return value of  [vim.diagnostic.get_prev()](https://neovim.io/doc/user/diagnostic.html#vim.diagnostic.get_prev())  instead.

The "win_id" parameter used by various functions is deprecated in favor of "winid"  [winid](https://neovim.io/doc/user/windows.html#winid)

[vim.diagnostic.JumpOpts](https://neovim.io/doc/user/diagnostic.html#vim.diagnostic.JumpOpts)  renamed its "cursor_position" field to "pos".

### HIGHLIGHTS

[TermCursorNC](https://neovim.io/doc/user/deprecated.html#TermCursorNC)  Unfocused  [terminal](https://neovim.io/doc/user/terminal.html#terminal)  windows do not have a cursor.

### LSP

[vim.lsp.util.jump_to_location](https://neovim.io/doc/user/deprecated.html#vim.lsp.util.jump_to_location)  Use  [vim.lsp.util.show_document()](https://neovim.io/doc/user/lsp.html#vim.lsp.util.show_document())  with  `{focus=true}`  instead.

[vim.lsp.buf.execute_command](https://neovim.io/doc/user/deprecated.html#vim.lsp.buf.execute_command)  Use  [Client:exec_cmd()](https://neovim.io/doc/user/lsp.html#Client%3Aexec_cmd())  instead.

[vim.lsp.buf.completion](https://neovim.io/doc/user/deprecated.html#vim.lsp.buf.completion)  Use  [vim.lsp.completion.get()](https://neovim.io/doc/user/lsp.html#vim.lsp.completion.get())  instead.

vim.lsp.buf_request_all The  `error`  key has been renamed to  `err`  inside the result parameter of the handler.

[vim.lsp.with()](https://neovim.io/doc/user/deprecated.html#vim.lsp.with())  Pass configuration to equivalent functions in  `vim.lsp.buf.*`.

[vim.lsp.handlers](https://neovim.io/doc/user/lsp.html#vim.lsp.handlers)  Does not support client-to-server response handlers. Only supports server-to-client requests/notification handlers.

[vim.lsp.handlers.signature_help()](https://neovim.io/doc/user/deprecated.html#vim.lsp.handlers.signature_help())  Use  [vim.lsp.buf.signature_help()](https://neovim.io/doc/user/lsp.html#vim.lsp.buf.signature_help())  instead.

`client.request()`  Use  [Client:request()](https://neovim.io/doc/user/lsp.html#Client%3Arequest())  instead.

`client.request_sync()`  Use  [Client:request_sync()](https://neovim.io/doc/user/lsp.html#Client%3Arequest_sync())  instead.

`client.notify()`  Use  [Client:notify()](https://neovim.io/doc/user/lsp.html#Client%3Anotify())  instead.

`client.cancel_request()`  Use  [Client:cancel_request()](https://neovim.io/doc/user/lsp.html#Client%3Acancel_request())  instead.

`client.stop()`  Use  [Client:stop()](https://neovim.io/doc/user/lsp.html#Client%3Astop())  instead.

`client.is_stopped()`  Use  [Client:is_stopped()](https://neovim.io/doc/user/lsp.html#Client%3Ais_stopped())  instead.

`client.supports_method()`  Use  [Client:supports_method()](https://neovim.io/doc/user/lsp.html#Client%3Asupports_method())  instead.

`client.on_attach()`  Use  [Client:on_attach()](https://neovim.io/doc/user/lsp.html#Client%3Aon_attach())  instead.

`vim.lsp.start_client()`  Use  [vim.lsp.start()](https://neovim.io/doc/user/lsp.html#vim.lsp.start())  instead.

### LUA

vim.region() Use  [getregionpos()](https://neovim.io/doc/user/vimfn.html#getregionpos())  instead.

[vim.highlight](https://neovim.io/doc/user/deprecated.html#vim.highlight)  Renamed to  [vim.hl](https://neovim.io/doc/user/lua.html#vim.hl).

vim.validate(opts: table) Use form 1. See  [vim.validate()](https://neovim.io/doc/user/lua.html#vim.validate()).

### VIMSCRIPT

[termopen()](https://neovim.io/doc/user/deprecated.html#termopen())  Use  [jobstart()](https://neovim.io/doc/user/vimfn.html#jobstart())  with  `{term: v:true}`.

### DEPRECATED IN 0.10[deprecated-0.10](https://neovim.io/doc/user/deprecated.html#deprecated-0.10)

### API

[nvim_buf_get_option()](https://neovim.io/doc/user/deprecated.html#nvim_buf_get_option())  Use  [nvim_get_option_value()](https://neovim.io/doc/user/api.html#nvim_get_option_value())  instead.

[nvim_buf_set_option()](https://neovim.io/doc/user/deprecated.html#nvim_buf_set_option())  Use  [nvim_set_option_value()](https://neovim.io/doc/user/api.html#nvim_set_option_value())  instead.

[nvim_call_atomic()](https://neovim.io/doc/user/deprecated.html#nvim_call_atomic())  Use  [nvim_exec_lua()](https://neovim.io/doc/user/api.html#nvim_exec_lua())  instead.

[nvim_get_option()](https://neovim.io/doc/user/deprecated.html#nvim_get_option())  Use  [nvim_get_option_value()](https://neovim.io/doc/user/api.html#nvim_get_option_value())  instead.

[nvim_set_option()](https://neovim.io/doc/user/deprecated.html#nvim_set_option())  Use  [nvim_set_option_value()](https://neovim.io/doc/user/api.html#nvim_set_option_value())  instead.

[nvim_win_get_option()](https://neovim.io/doc/user/deprecated.html#nvim_win_get_option())  Use  [nvim_get_option_value()](https://neovim.io/doc/user/api.html#nvim_get_option_value())  instead.

[nvim_win_set_option()](https://neovim.io/doc/user/deprecated.html#nvim_win_set_option())  Use  [nvim_set_option_value()](https://neovim.io/doc/user/api.html#nvim_set_option_value())  instead.

### CHECKHEALTH

[health#report_error](https://neovim.io/doc/user/deprecated.html#health%23report_error)  [vim.health.report_error()](https://neovim.io/doc/user/deprecated.html#vim.health.report_error())  Use  [vim.health.error()](https://neovim.io/doc/user/health.html#vim.health.error())  instead.

[health#report_info](https://neovim.io/doc/user/deprecated.html#health%23report_info)  [vim.health.report_info()](https://neovim.io/doc/user/deprecated.html#vim.health.report_info())  Use  [vim.health.info()](https://neovim.io/doc/user/health.html#vim.health.info())  instead.

[health#report_ok](https://neovim.io/doc/user/deprecated.html#health%23report_ok)  [vim.health.report_ok()](https://neovim.io/doc/user/deprecated.html#vim.health.report_ok())  Use  [vim.health.ok()](https://neovim.io/doc/user/health.html#vim.health.ok())  instead.

[health#report_start](https://neovim.io/doc/user/deprecated.html#health%23report_start)  [vim.health.report_start()](https://neovim.io/doc/user/deprecated.html#vim.health.report_start())  Use  [vim.health.start()](https://neovim.io/doc/user/health.html#vim.health.start())  instead.

[health#report_warn](https://neovim.io/doc/user/deprecated.html#health%23report_warn)  [vim.health.report_warn()](https://neovim.io/doc/user/deprecated.html#vim.health.report_warn())  Use  [vim.health.warn()](https://neovim.io/doc/user/health.html#vim.health.warn())  instead.

### DIAGNOSTICS

Configuring  [diagnostic-signs](https://neovim.io/doc/user/diagnostic.html#diagnostic-signs)  using  [:sign-define](https://neovim.io/doc/user/sign.html#%3Asign-define)  or  [sign_define()](https://neovim.io/doc/user/vimfn.html#sign_define()). Use the "signs" key of  [vim.diagnostic.config()](https://neovim.io/doc/user/diagnostic.html#vim.diagnostic.config())  instead.

vim.diagnostic functions:

[vim.diagnostic.disable()](https://neovim.io/doc/user/deprecated.html#vim.diagnostic.disable())  Use  [vim.diagnostic.enable()](https://neovim.io/doc/user/diagnostic.html#vim.diagnostic.enable())

[vim.diagnostic.is_disabled()](https://neovim.io/doc/user/deprecated.html#vim.diagnostic.is_disabled())  Use  [vim.diagnostic.is_enabled()](https://neovim.io/doc/user/diagnostic.html#vim.diagnostic.is_enabled())

Legacy signature:  `vim.diagnostic.enable(buf:number, namespace:number)`

### LSP

[vim.lsp.util.get_progress_messages()](https://neovim.io/doc/user/deprecated.html#vim.lsp.util.get_progress_messages())  Use  [vim.lsp.status()](https://neovim.io/doc/user/lsp.html#vim.lsp.status())  instead.

[vim.lsp.get_active_clients()](https://neovim.io/doc/user/deprecated.html#vim.lsp.get_active_clients())  Use  [vim.lsp.get_clients()](https://neovim.io/doc/user/lsp.html#vim.lsp.get_clients())  instead.

[vim.lsp.for_each_buffer_client()](https://neovim.io/doc/user/deprecated.html#vim.lsp.for_each_buffer_client())  Use  [vim.lsp.get_clients()](https://neovim.io/doc/user/lsp.html#vim.lsp.get_clients())  instead.

[vim.lsp.util.trim_empty_lines()](https://neovim.io/doc/user/deprecated.html#vim.lsp.util.trim_empty_lines())  Use  [vim.split()](https://neovim.io/doc/user/lua.html#vim.split())  with  `trimempty`  instead.

[vim.lsp.util.try_trim_markdown_code_blocks()](https://neovim.io/doc/user/deprecated.html#vim.lsp.util.try_trim_markdown_code_blocks())

[vim.lsp.util.set_lines()](https://neovim.io/doc/user/deprecated.html#vim.lsp.util.set_lines())

[vim.lsp.util.extract_completion_items()](https://neovim.io/doc/user/deprecated.html#vim.lsp.util.extract_completion_items())

[vim.lsp.util.parse_snippet()](https://neovim.io/doc/user/deprecated.html#vim.lsp.util.parse_snippet())

[vim.lsp.util.text_document_completion_list_to_complete_items()](https://neovim.io/doc/user/deprecated.html#vim.lsp.util.text_document_completion_list_to_complete_items())

[vim.lsp.util.lookup_section()](https://neovim.io/doc/user/deprecated.html#vim.lsp.util.lookup_section())  Use  [vim.tbl_get()](https://neovim.io/doc/user/lua.html#vim.tbl_get())  instead:

local keys = vim.split(section, '.', { plain = true })
local  vim.tbl_get(table, unpack(keys))

LUA

[vim.loop](https://neovim.io/doc/user/deprecated.html#vim.loop)  Use  [vim.uv](https://neovim.io/doc/user/lua.html#vim.uv)  instead.

[vim.tbl_add_reverse_lookup()](https://neovim.io/doc/user/deprecated.html#vim.tbl_add_reverse_lookup())

[vim.tbl_flatten()](https://neovim.io/doc/user/deprecated.html#vim.tbl_flatten())  Use  [Iter:flatten()](https://neovim.io/doc/user/lua.html#Iter%3Aflatten())  instead.

[vim.tbl_islist()](https://neovim.io/doc/user/deprecated.html#vim.tbl_islist())  Use  [vim.islist()](https://neovim.io/doc/user/lua.html#vim.islist())  instead.

### OPTIONS

The "term_background" UI option  [ui-ext-options](https://neovim.io/doc/user/api-ui-events.html#ui-ext-options)  is deprecated and no longer populated. Background color detection is now performed in Lua by the Nvim core, not the TUI.

### TREESITTER

[LanguageTree:for_each_child()](https://neovim.io/doc/user/deprecated.html#LanguageTree%3Afor_each_child())  Use  [LanguageTree:children()](https://neovim.io/doc/user/treesitter.html#LanguageTree%3Achildren())  (non-recursive) instead.
