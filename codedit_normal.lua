--codedit normalization
local buffer = require'codedit_buffer'
local str = require'codedit_str'

buffer.eol_spaces = 'remove' --leave, remove.
buffer.eof_lines = 1 --leave, remove, ensure, or a number.
buffer.convert_to_tabs = true --convert indentation spaces to tabs based on current tabsize

function buffer:remove_eol_spaces() --remove any spaces past eol
	for line = 1, self:last_line() do
		self:setline(line, str.rtrim(self:getline(line)))
	end
end

function buffer:ensure_eof_line() --add an empty line at eof if there is none
	if not self:isempty(self:last_line()) then
		self:insert_line(self:last_line() + 1, '')
	end
end

function buffer:remove_eof_lines() --remove any empty lines at eof, except the first line
	while self:last_line() > 1 and self:isempty(self:last_line()) do
		self:remove_line(self:last_line())
	end
end

function buffer:convert_indent_to_tabs()
	for line = 1, self:last_line() do
		local indent_col = self:indent_col(line)
		local indent_vcol = self:visual_col(line, indent_col)
		local tabs, spaces = self:tabs_and_spaces(1, indent_vcol)
		self:setline(line, string.rep('\t', tabs) .. string.rep(' ', spaces) .. self:sub(line, indent_col))
	end
end

function buffer:normalize()
	if self.eol_spaces == 'remove' then
		self:remove_eol_spaces()
	end
	if self.convert_to_tabs then
		self:convert_indent_to_tabs()
	end
	if self.eof_lines == 'ensure' then
		self:ensure_eof_line()
	elseif self.eof_lines == 'remove' then
		self:remove_eof_lines()
	elseif type(self.eof_lines) == 'number' then
		self:remove_eof_lines()
		for i = 1, self.eof_lines do
			self:insert_line(self:last_line() + 1, '')
		end
	end
end


if not ... then require'codedit_demo' end
