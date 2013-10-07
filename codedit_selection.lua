--codedit selection object: selecting contiguous text between two line,col pairs.
--line1,col1 is the first selected char and line2,col2 is the char immediately after the last selected char.
local glue = require'glue'

local selection = {
	color = nil, --color override
}

function selection:new(editor, visible)
	self = glue.inherit({editor = editor, buffer = editor.buffer, visible = visible}, self)
	self:reset(1, 1)
	self.editor.selections[self] = true
	return self
end

function selection:free()
	self.editor.selections[self] = nil
end

--selection querying

function selection:isempty()
	return self.line2 == self.line1 and self.col2 == self.col1
end

--goes top-down and left-to-rigth
function selection:isforward()
	return self.line1 < self.line2 or (self.line1 == self.line2 and self.col1 <= self.col2)
end

--endpoints, ordered
function selection:endpoints()
	if self:isforward() then
		return self.line1, self.col1, self.line2, self.col2
	else
		return self.line2, self.col2, self.line1, self.col1
	end
end

--column range of one selection line
function selection:cols(line)
	local line1, col1, line2, col2 = self:endpoints()
	local col1 = line == line1 and col1 or 1
	local col2 = line == line2 and col2 or self.buffer:last_col(line) + 1
	return col1, col2
end

function selection:next_line(line)
	line = line and line + 1 or math.min(self.line1, self.line2)
	if line > math.max(self.line1, self.line2) then
		return
	end
	return line, self:cols(line)
end

function selection:lines()
	return self.next_line, self
end

--the range of lines that the selection covers fully or partially
function selection:line_range()
	local line1, col1, line2, col2 = self:endpoints()
	if not self:isempty() and col2 == 1 then
		return line1, line2 - 1
	else
		return line1, line2
	end
end

function selection:select()
	return self.buffer:select_string(self:endpoints())
end

function selection:contents()
	return self.buffer:contents(self:select())
end

--changing the selection

--empty and re-anchor the selection
function selection:reset(line, col)
	self.line1, self.col1 = self.buffer:clamp_pos(line, col)
	self.line2, self.col2 = self.line1, self.col1
end

--move selection's free endpoint
function selection:extend(line, col)
	self.line2, self.col2 = self.buffer:clamp_pos(line, col)
end

--reverse selection's direction
function selection:reverse()
	self.line1, self.col1, self.line2, self.col2 =
		self.line2, self.col2, self.line1, self.col1
end

--set selection endpoints, preserving or setting its direction
function selection:set(line1, col1, line2, col2, forward)
	if forward == nil then
		forward = self:isforward()
	end
	self:reset(line1, col1)
	self:extend(line2, col2)
	if forward ~= self:isforward() then
		self:reverse()
	end
end

function selection:select_all()
	self:set(1, 1, 1/0, 1/0, true)
end

function selection:reset_to_cursor(cur)
	self:reset(cur.line, cur.col)
end

function selection:extend_to_cursor(cur)
	self:extend(cur.line, cur.col)
end

function selection:set_to_selection(sel)
	self:set(sel.line1, sel.col1, sel.line2, sel.col2, sel:isforward())
end

--selection-based editing

function selection:remove()
	if self:isempty() then return end
	local line1, col1, line2, col2 = self:endpoints()
	self.buffer:remove_string(line1, col1, line2, col2)
	self:reset(line1, col1)
end

function selection:indent()
	local line1, line2 = self:line_range()
	for line = line1, line2 do
		self.buffer:indent_line(line)
	end
	self:set(line1, 1, line2 + 1, 1)
end

function selection:outdent()
	local line1, line2 = self:line_range()
	for line = line1, line2 do
		self.buffer:outdent_line(line)
	end
	self:set(line1, 1, line2 + 1, 1)
end

function selection:move_up()
	local line1, line2 = self:line_range()
	if line1 == 1 then
		return
	end
	for line = line1, line2 do
		self.buffer:move_line(line, line - 1)
	end
	self:set(line1 - 1, 1, line2 - 1 + 1, 1)
end

function selection:move_down()
	local line1, line2 = self:line_range()
	if line2 == self.buffer:last_line() then
		return
	end
	for line = line2, line1, -1 do
		self.buffer:move_line(line, line + 1)
	end
	self:set(line1 + 1, 1, line2 + 1 + 1, 1)
end

--hit testing

function selection:hit_test(x, y)
	for line1, col1, col2 in self:lines() do
		if self.editor:hit_test_rect(x, y, line1, col1, line1, col2) then
			return true
		end
	end
	return false
end


if not ... then require'codedit_demo' end

return selection
