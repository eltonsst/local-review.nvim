return {
	active = false,
	comments = {},
	buffers = {},
	next_id = 1,
	namespace = vim.api.nvim_create_namespace("local-review"),
	root = nil,
}
