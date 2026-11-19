--!strict

-- Append-only binary writer backed by a resizable Luau buffer.
local StreamBuffer = {}
StreamBuffer.__index = StreamBuffer

local DEFAULT_CAPACITY = 64
local MAX_CAPACITY = 1_073_741_824

export type Writer = typeof(setmetatable({} :: {
	buf: buffer,
	len: number,
}, StreamBuffer))

function StreamBuffer.new(initialCapacity: number?): Writer
	local capacity = initialCapacity or DEFAULT_CAPACITY
	assert(capacity >= 0 and capacity <= MAX_CAPACITY and capacity % 1 == 0, "Invalid initial capacity")

	return setmetatable({
		buf = buffer.create(capacity),
		len = 0,
	}, StreamBuffer)
end

-- Ensure room for this many bytes after len without advancing it.
-- Read buf again after any operation that can grow it.
function StreamBuffer.reserve(self: Writer, additionalBytes: number)
	assert(additionalBytes >= 0 and additionalBytes % 1 == 0, "Invalid byte count")

	local required = self.len + additionalBytes
	local capacity = buffer.len(self.buf)
	if required <= capacity then
		return
	end

	assert(required <= MAX_CAPACITY, "Buffer capacity limit exceeded")
	local newCapacity = math.min(MAX_CAPACITY, math.max(DEFAULT_CAPACITY, capacity * 2, required))
	local newBuffer = buffer.create(newCapacity)
	buffer.copy(newBuffer, 0, self.buf, 0, self.len)
	self.buf = newBuffer
end

-- Append a region for a caller to fill and return its zero-based offset.
function StreamBuffer.allocRegion(self: Writer, byteCount: number): number
	local offset = self.len
	self:reserve(byteCount)
	self.len = offset + byteCount
	return offset
end

function StreamBuffer.writeu8(self: Writer, value: number)
	local offset = self.len
	self:reserve(1)
	buffer.writeu8(self.buf, offset, value)
	self.len = offset + 1
end

function StreamBuffer.writeu16(self: Writer, value: number)
	local offset = self.len
	self:reserve(2)
	buffer.writeu16(self.buf, offset, value)
	self.len = offset + 2
end

function StreamBuffer.writeu32(self: Writer, value: number)
	local offset = self.len
	self:reserve(4)
	buffer.writeu32(self.buf, offset, value)
	self.len = offset + 4
end

function StreamBuffer.writestring(self: Writer, value: string)
	local offset = self.len
	local byteCount = #value
	self:reserve(byteCount)
	buffer.writestring(self.buf, offset, value)
	self.len = offset + byteCount
end

-- Prefix the raw string bytes with their little-endian u32 length.
function StreamBuffer.writeLenString(self: Writer, value: string)
	local offset = self.len
	local byteCount = #value
	self:reserve(4 + byteCount)
	buffer.writeu32(self.buf, offset, byteCount)
	buffer.writestring(self.buf, offset + 4, value)
	self.len = offset + 4 + byteCount
end

-- Return only the bytes written or allocated so far.
function StreamBuffer.tostring(self: Writer): string
	return buffer.readstring(self.buf, 0, self.len)
end

return StreamBuffer
