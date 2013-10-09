--codedit line buffer object
local glue = require'glue'
local str = require'codedit_str'
local tabs = require'codedit_tabs'

local buffer = {
	line_terminator = nil, --line terminator to use when retrieving lines as a string. nil means autodetect.
	default_line_terminator = '\n', --line terminator to use when autodetection fails.
}

function buffer:new(editor, text)
	self = glue.inherit({editor = editor, view = editor}, self)
	self.line_terminator =
		self.line_terminator or
		self:detect_line_terminator(text) or
		self.default_line_terminator
	self.lines = {''} --can't have zero lines
	self.changed = {} --{flag = nil/true/false}; all flags are set to true whenever the buffer changes.
	if text then
		self:insert_string(1, 1, text) --insert text without undo stack
	end
	self.changed.file = false --"file" is the default changed flag to use for saving.
	self.undo_stack = {}
	self.redo_stack = {}
	self.undo_group = nil
	return self
end

--text analysis

--class method that returns the most common line terminator in a string, or nil for failure
function buffer:detect_line_terminator(s)
	local rn = str.count(s, '\r\n') --win lines
	local r  = str.count(s, '\r') --mac lines
	local n  = str.count(s, '\n') --unix lines (default)
	if rn > n and rn > r then
		return '\r\n'
	elseif r > n then
		return '\r'
	end
end

--detect indent type and tab size of current buffer
function buffer:detect_indent()
	local tabs, spaces = 0, 0
	for line = 1, self:last_line() do
		local tabs1, spaces1 = str.indent_counts(self:getline(line))
		tabs = tabs + tabs1
		spaces = spaces + spaces1
	end
	--TODO: finish this
end

--low-level line-based interface

function buffer:getline(line)
	return self.lines[line]
end

function buffer:last_line()
	return #self.lines
end

function buffer:contents(lines)
	return table.concat(lines or self.lines, self.line_terminator)
end

function buffer:invalidate()
	for k in pairs(self.changed) do
		self.changed[k] = true
	end
end

function buffer:insert_line(line, s)
	table.insert(self.lines, line, s)
	self:undo_command('remove_line', line)
	self:invalidate()
end

function buffer:remove_line(line)
	local s = table.remove(self.lines, line)
	self:undo_command('insert_line', line, s)
	self:invalidate()
	return s
end

function buffer:setline(line, s)
	self:undo_command('setline', line, self:getline(line))
	self.lines[line] = s
	self:invalidate()
end

--switch two lines with one another
function buffer:move_line(line1, line2)
	local s1 = self:getline(line1)
	local s2 = self:getline(line2)
	if not s1 or not s2 then return end
	self:setline(line1, s2)
	self:setline(line2, s1)
end

--position-based interface

function buffer:last_col(line)
	return str.len(self:getline(line))
end

function buffer:end_pos()
	return self:last_line(), self:last_col(self:last_line()) + 1
end

function buffer:indent_col(line)
	return (str.first_nonspace(self:getline(line)))
end

function buffer:isempty(line)
	local s = self:getline(line)
	local _, i = str.first_nonspace(s)
	return i > #s
end

function buffer:sub(line, col1, col2)
	return str.sub(self:getline(line), col1, col2)
end

--position left of some char, unclamped
function buffer:left_pos(line, col)
	if col > 1 then
		return line, col - 1
	elseif self:getline(line - 1) then
		return line - 1, self:last_col(line - 1) + 1
	else
		return line - 1, 1
	end
end

--position right of some char, unclamped
function buffer:right_pos(line, col, restrict_eol)
	if not restrict_eol or (self:getline(line) and col < self:last_col(line) + 1) then
		return line, col + 1
	else
		return line + 1, 1
	end
end

--position some-chars distance from some char, unclamped
function buffer:near_pos(line, col, chars, restrict_eol)
	local method = chars > 0 and self.right_pos or self.left_pos
	chars = math.abs(chars)
	while chars > 0 do
		line, col = method(self, line, col, restrict_eol)
		chars = chars - 1
	end
	return line, col
end

--clamp a char position to the available text
function buffer:clamp_pos(line, col)
	if line < 1 then
		return 1, 1
	elseif line > self:last_line() then
		return self:end_pos()
	else
		return line, math.min(math.max(col, 1), self:last_col(line) + 1)
	end
end

--select the string between two valid, subsequent positions in the text
function buffer:select_string(line1, col1, line2, col2)
	local lines = {}
	if line1 == line2 then
		table.insert(lines, self:sub(line1, col1, col2 - 1))
	else
		table.insert(lines, self:sub(line1, col1))
		for line = line1 + 1, line2 - 1 do
			table.insert(lines, self:getline(line))
		end
		table.insert(lines, self:sub(line2, 1, col2 - 1))
	end
	return lines
end

--extend the buffer up to (line,col-1) so we can edit there.
function buffer:extend(line, col)
	while line > self:last_line() do
		self:insert_line(self:last_line() + 1, '')
	end
	local last_col = self:last_col(line)
	if col > last_col + 1 then
		self:setline(line, self:getline(line) .. string.rep(' ', col - last_col - 1))
	end
end

--insert a multiline string at a specific position in the text, returning the position after the last character.
function buffer:insert_string(line, col, s)
	self:extend(line, col)
	local s1 = self:sub(line, 1, col - 1)
	local s2 = self:sub(line, col)
	s = s1 .. s .. s2
	local first_line = true
	for _,s in str.lines(s) do
		if first_line then
			self:setline(line, s)
			first_line = false
		else
			line = line + 1
			self:insert_line(line, s)
		end
	end
	return line, self:last_col(line) - #s2 + 1
end

--remove the string between two subsequent positions in the text.
--line2,col2 is the position right after (not of!) the last character to be removed.
function buffer:remove_string(line1, col1, line2, col2)
	line1, col1 = self:clamp_pos(line1, col1)
	line2, col2 = self:clamp_pos(line2, col2)
	local s1 = self:sub(line1, 1, col1 - 1)
	local s2 = self:sub(line2, col2)
	for line = line2, line1 + 1, -1 do
		self:remove_line(line)
	end
	self:setline(line1, s1 .. s2)
end

--tab expansion (adding the concept of visual columns)

function buffer:tab_width(vcol)               return tabs.tab_width(vcol, self.view.tabsize) end
function buffer:next_tabstop(vcol)            return tabs.next_tabstop(vcol, self.view.tabsize) end
function buffer:tabs_and_spaces(vcol1, vcol2) return tabs.tabs_and_spaces(vcol1, vcol2, self.view.tabsize) end
function buffer:prev_tabstop(vcol)            return tabs.prev_tabstop(vcol, self.view.tabsize) end
function buffer:next_tabstop(vcol)            return tabs.next_tabstop(vcol, self.view.tabsize) end

function buffer:visual_col(line, col)
	local s = self:getline(line)
	if s then
		return tabs.visual_col(s, col, self.view.tabsize)
	else
		return col --outside eof visual columns and real columns are the same
	end
end

function buffer:real_col(line, vcol)
	local s = self:getline(line)
	if s then
		return tabs.real_col(s, vcol, self.view.tabsize)
	else
		return vcol --outside eof visual columns and real columns are the same
	end
end

--real col on a line, that is vertically aligned to the same real col on a different line
function buffer:aligned_col(target_line, line, col)
	return self:real_col(target_line, self:visual_col(line, col))
end

--tabstop position left of some char, unclamped
function buffer:left_tabstop_pos(line, col)
	local vcol = self:visual_col(line, col)
	local ts_vcol = self:prev_tabstop(vcol)
	local ts_col = self:real_col(line, ts_vcol)
	local ns_col = str.prev_nonspace(self:getline(line), col)
	return line, math.max(ts_col, ns_col)
end

function buffer:right_tabstop_pos(line, col)
	local vcol = self:visual_col(line, col)
	local ts_vcol = self:next_tabstop(vcol)
	local ts_col = self:real_col(line, ts_vcol)
	local ns_col = str.next_nonspace(self:getline(line), col)
	return line, math.min(ts_col, ns_col)
end

--editing based on tab expansion

--insert a tab or spaces up to the next tabstop. returns the cursor at the tabstop, where the indented text is.
function buffer:insert_tab(line, col, insert_tabs)
	if insert_tabs == 'always' or
	   (insert_tabs == 'indent' and self:getline(line) and col <= self:indent_col(line))
	then
		return self:insert_string(line, col, '\t')
	else
		local vcol = self:visual_col(line, col)
		return self:insert_string(line, col, string.rep(' ', self:tab_width(vcol)))
	end
end

function buffer:indent_line(line, insert_tabs)
	return self:insert_tab(line, 1, insert_tabs)
end

--remove a tab or all the spaces up to the next tabstop, if any. return the number of removed characters.
function buffer:remove_tab(line, col)
	local s = self:getline(line)
	if not s then return 0 end
	--to_remove is the total number of spaces + tabs to remove, and we can remove at most 1 tab.
	local to_remove = self:tab_width(self:visual_col(line, col))
	local total_removed = 0
	local tab_removed = false
	local i = str.byte_index(s, col)
	while i and to_remove > 0 and not tab_removed and str.isspace(s, i) do
		tab_removed = str.istab(s, i)
		to_remove = to_remove - 1
		total_removed = total_removed + 1
		i = str.next(s, i)
	end
	self:remove_string(line, col, line, col + total_removed)
	return total_removed
end

function buffer:outdent_line(line)
	return self:remove_tab(line, 1)
end

--navigation at word boundaries

function buffer:left_word_pos(line, col, word_chars)
	if line < 1 or col <= 1 then
		return self:left_pos(line, col)
	elseif line > self:last_line() then
		return self:end_pos()
	elseif col > self:last_col(line) + 1 then
		return line, self:last_col(line) + 1
	else
		local s = self:getline(line)
		local prev_col = str.prev_word_break(s, col, word_chars)
		if not prev_col then
			return self:left_pos(line, col)
		end
		return line, prev_col
	end
end

function buffer:right_word_pos(line, col, word_chars)
	local s = self:getline(line)
	if not s or col > self:last_col(line) then
		return self:right_pos(line, col, true)
	end
	local next_col = str.next_word_break(s, col, word_chars)
	if not next_col then
		return self:right_pos(line, col)
	end
	return line, next_col
end

--text reflowing. return the position after the last inserted character.
function buffer:reflow(line1, col1, line2, col2, line_width, word_chars)
	local lines = self:select_string(line1, col1, line2, col2)
	local lines = str.reflow(lines, line_width, word_chars)
	self:remove_string(line1, col1, line2, col2)
	return self:insert_string(line1, col1, self:contents(lines))
end


if not ... then require'codedit_demo' end

return buffer
