" vim600: set foldmethod=marker:
"
" Mercurial extension for VCSCommand.
"
" this file is maintained by https://github.com/serialdoom
" There are some comments "p4-plugin" through the code that
" mark my changes and what i have tested. Please try and
" keep the comments consistent if you change anything.
"
" Original infos :
" Maintainer:    Bob Hiestand <bob.hiestand@gmail.com>
" License:
" Copyright (c) Bob Hiestand
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to
" deal in the Software without restriction, including without limitation the
" rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
" sell copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
" FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
" IN THE SOFTWARE.
"
" Section: Documentation {{{1
"
" Options documentation: {{{2
"
" VCSCommandP4Exec
"   This variable specifies the mercurial executable.  If not set, it defaults
"   to 'p4' executed from the user's executable path.
"
" VCSCommandp4DiffExt
"   This variable, if set, sets the external diff program used by Subversion.
"
" VCSCommandp4DiffOpt
"   This variable, if set, determines the options passed to the p4 diff
"   command (such as 'u', 'w', or 'b').

" Section: Plugin header {{{1

if exists('VCSCommandDisableAll')
	finish
endif

if v:version < 700
	echohl WarningMsg|echomsg 'VCSCommand requires at least VIM 7.0'|echohl None
	finish
endif

if !exists('g:loaded_VCSCommand')
	runtime plugin/vcscommand.vim
endif

if !executable(VCSCommandGetOption('VCSCommandP4Exec', 'p4'))
	" P4 is not installed
	finish
endif

let s:save_cpo=&cpo
set cpo&vim

" Section: Variable initialization {{{1

let s:p4Functions = {}

" Section: Utility functions {{{1

" Function: s:Executable() {{{2
" Returns the executable used to invoke p4 suitable for use in a shell
" command.
function! s:Executable()
	return shellescape(VCSCommandGetOption('VCSCommandP4Exec', 'p4'))
endfunction

" Function: s:DoCommand(cmd, cmdName, statusText, options) {{{2
" Wrapper to VCSCommandDoCommand to add the name of the P4 executable to the
" command argument.
function! s:DoCommand(cmd, cmdName, statusText, options)
	if VCSCommandGetVCSType(expand('%')) == 'P4'
		let fullCmd = s:Executable() . ' ' . a:cmd
		return VCSCommandDoCommand(fullCmd, a:cmdName, a:statusText, a:options)
	else
		throw 'P4 VCSCommand plugin called on non-P4 item.'
	endif
endfunction

" Section: VCS function implementations {{{1

" Function: s:p4Functions.Identify(buffer) {{{2
function! s:p4Functions.Identify(buffer)
	let oldCwd = VCSCommandChangeToCurrentFileDir(resolve(bufname(a:buffer)))
	try
		call s:VCSCommandUtility.system(s:Executable() . ' -s files ...')
		if(v:shell_error)
			return 0
		else
			return g:VCSCOMMAND_IDENTIFY_INEXACT
		endif
	finally
		call VCSCommandChdir(oldCwd)
	endtry
endfunction

" Function: s:p4Functions.Add() {{{2
function! s:p4Functions.Add(argList)
    """ TODO Not tested
	return s:DoCommand(join(['add'] + a:argList, ' '), 'add', join(a:argList, ' '), {})
endfunction

" Function: s:p4Functions.Annotate(argList) {{{2
function! s:p4Functions.Annotate(argList)
    """ p4-plugin changed, tested
    let options = ''
	if len(a:argList) == 0
        let caption = 'p4 annotate'
        let options = ''
	elseif len(a:argList) == 1 && a:argList[0] !~ '^-'
		let caption = a:argList[0]
		let options = ' ' . caption
	else
		let caption = join(a:argList, ' ')
		let options = ' '
	endif

	return s:DoCommand('annotate' . options . ' <VCSCOMMANDFILE>', 'annotate', caption, {})
endfunction

" Function: s:p4Functions.Commit(argList) {{{2
function! s:p4Functions.Commit(argList)
    """ TODO p4-plugin not changed, not tested
	try
		return s:DoCommand('commit -v -l "' . a:argList[0] . '"', 'commit', '', {})
	catch /Version control command failed.*nothing changed/
		echomsg 'No commit needed.'
	endtry
endfunction

" Function: s:p4Functions.Delete() {{{2
function! s:p4Functions.Delete(argList)
    """ TODO p4-plugin not changed, not tested
	return s:DoCommand(join(['remove'] + a:argList, ' '), 'remove', join(a:argList, ' '), {})
endfunction

" Function: s:p4Functions.Diff(argList) {{{2
function! s:p4Functions.Diff(argList)
    """ p4-plugin changed, tested
	if len(a:argList) == 0
		let revOptions = []
		let caption = ''
	elseif len(a:argList) <= 2 && match(a:argList, '^-') == -1
		let revOptions = []
		let caption = a:argList[0]
	else
		" Pass-through
		let caption = join(a:argList, ' ')
		let revOptions = a:argList
	endif

	let p4DiffExt = VCSCommandGetOption('VCSCommandp4DiffExt', '')
	if p4DiffExt == ''
		let diffExt = []
	else
		let diffExt = ['--diff-cmd ' . p4DiffExt]
	endif

	let p4DiffOpt = VCSCommandGetOption('VCSCommandp4DiffOpt', '')
	if p4DiffOpt == ''
		let diffOptions = ['-dNpaur ']
	else
		let diffOptions = ['-x -' . p4DiffOpt]
	endif

    " TODO check caption and replace with filename
	return s:DoCommand(join(['diff'] + diffExt + diffOptions + revOptions) . ' <VCSCOMMANDFILE>', 'diff', caption, {})
endfunction

" Function: s:p4Functions.Info(argList) {{{2
function! s:p4Functions.Info(argList)
    """ p4-plugin changed, tested
	return s:DoCommand(join(['fstat'] + a:argList, ' ') . ' <VCSCOMMANDFILE>', 'log', join(a:argList, ' '), {})
endfunction

" Function: s:p4Functions.GetBufferInfo() {{{2
" Provides version control details for the current file.  Current version
" number and current repository version number are required to be returned by
" the vcscommand plugin.
" Returns: List of results:  [revision, repository, branch]

function! s:p4Functions.GetBufferInfo()
    """ TODO p4-plugin not changed, not tested
	let originalBuffer = VCSCommandGetOriginalBuffer(bufnr('%'))
	let fileName = bufname(originalBuffer)
	let statusText = s:VCSCommandUtility.system(s:Executable() . ' status -- "' . fileName . '"')
	if(v:shell_error)
		return []
	endif

	" File not under P4 control.
	if statusText =~ '^?'
		return ['Unknown']
	endif

	let parentsText = s:VCSCommandUtility.system(s:Executable() . ' parents -- "' . fileName . '"')
	let revision = matchlist(parentsText, '^changeset:\s\+\(\S\+\)\n')[1]

	let logText = s:VCSCommandUtility.system(s:Executable() . ' log -- "' . fileName . '"')
	let repository = matchlist(logText, '^changeset:\s\+\(\S\+\)\n')[1]

	if revision == ''
		" Error
		return ['Unknown']
	elseif statusText =~ '^A'
		return ['New', 'New']
	else
		return [revision, repository]
	endif
endfunction

" Function: s:p4Functions.Log(argList) {{{2
function! s:p4Functions.Log(argList)
    """ p4-plugin changed, tested
	if len(a:argList) == 0
		let options = []
		let caption = ''
	elseif len(a:argList) <= 2 && match(a:argList, '^-') == -1
		let options = ''
		let caption = options[0]
	else
		" Pass-through
		let options = a:argList
		let caption = join(a:argList, ' ')
	endif

	let resultBuffer = s:DoCommand(join(['filelog'] + options) . ' <VCSCOMMANDFILE>', 'log', caption, {})
	return resultBuffer
endfunction

" Function: s:p4Functions.Revert(argList) {{{2
function! s:p4Functions.Revert(argList)
    """ TODO p4-plugin not changed, not tested
	return s:DoCommand('revert', 'revert', '', {})
endfunction

" Function: s:p4Functions.Review(argList) {{{2
function! s:p4Functions.Review(argList)
    """ p4-plugin changed, tested
	if len(a:argList) == 0
		let versiontag = '' " expand('%:p')
		let versionOption = ''
	else
		let versiontag = a:argList[0]
		let versionOption = '' "' -r ' . versiontag . ' '
	endif

	return s:DoCommand('print ' . versionOption . ' <VCSCOMMANDFILE>', 'review', versiontag, {})
endfunction

" Function: s:p4Functions.Status(argList) {{{2
function! s:p4Functions.Status(argList)
    """ TODO p4-plugin not changed, not tested
	let options = ['-A', '-v']
	if len(a:argList) != 0
		let options = a:argList
	endif
	return s:DoCommand(join(['status'] + options, ' '), 'status', join(options, ' '), {})
endfunction

" Function: s:p4Functions.Update(argList) {{{2
function! s:p4Functions.Update(argList)
    """ TODO p4-plugin not changed, not tested
	return s:DoCommand('update', 'update', '', {})
endfunction

" Annotate setting {{{2
let s:p4Functions.AnnotateSplitRegex = '\d\+: '

" Section: Plugin Registration {{{1
let s:VCSCommandUtility = VCSCommandRegisterModule('P4', expand('<sfile>'), s:p4Functions, [])

let &cpo = s:save_cpo
