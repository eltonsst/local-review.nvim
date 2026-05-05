local M = {}

local config = {
	context_lines = 5,
	keymap = nil,
}

local state = {
	active = false,
	comments = {},
	buffers = {},
	next_id = 1,
	namespace = vim.api.nvim_create_namespace("local-review"),
	root = nil,
}

local function project_root_for(path)
	local start_dir = path ~= "" and vim.fn.fnamemodify(path, ":p:h") or vim.fn.getcwd()
	local result = vim.fn.systemlist({ "git", "-C", start_dir, "rev-parse", "--show-toplevel" })

	if vim.v.shell_error == 0 and result[1] and result[1] ~= "" then
		return result[1]
	end

	return vim.fn.getcwd()
end

local function relative_path(root, path)
	if path == "" then
		return "[No Name]"
	end

	local normalized_root = vim.fs.normalize(root)
	local normalized_path = vim.fs.normalize(path)
	local root_prefix = normalized_root .. "/"

	if vim.startswith(normalized_path, root_prefix) then
		return normalized_path:sub(#root_prefix + 1)
	end

	return normalized_path
end

local function capture_location(context_lines)
	context_lines = context_lines or config.context_lines

	local bufnr = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)
	local root = project_root_for(path)
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local line_count = vim.api.nvim_buf_line_count(bufnr)

	local context_before = vim.api.nvim_buf_get_lines(bufnr, math.max(0, row - 1 - context_lines), row - 1, false)
	local target = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
	local context_after = vim.api.nvim_buf_get_lines(bufnr, row, math.min(line_count, row + context_lines), false)

	return {
		bufnr = bufnr,
		root = root,
		file = relative_path(root, path),
		line = row,
		target = target,
		context_before = context_before,
		context_after = context_after,
	}
end

local function open_comment_window(location, on_confirm, initial_text)
	local width = math.min(80, math.floor(vim.o.columns * 0.8))
	local height = math.min(12, math.floor(vim.o.lines * 0.4))
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "wipe"
	vim.bo[bufnr].filetype = "markdown"
	vim.bo[bufnr].swapfile = false

	if initial_text and initial_text ~= "" then
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(initial_text, "\n", { plain = true }))
	end

	local winid = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = string.format(" Review %s:%d ", location.file, location.line),
		title_pos = "center",
	})

	vim.wo[winid].wrap = true
	vim.wo[winid].linebreak = true

	local function close_window()
		if vim.api.nvim_win_is_valid(winid) then
			vim.api.nvim_win_close(winid, true)
		end
	end

	local function confirm()
		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local comment = vim.trim(table.concat(lines, "\n"))

		close_window()

		if comment == "" then
			vim.notify("Local review comment cancelled: empty comment", vim.log.levels.INFO)
			return
		end

		on_confirm(comment)
	end

	vim.keymap.set("n", "<C-s>", confirm, { buffer = bufnr, nowait = true, desc = "Save local review comment" })
	vim.keymap.set("i", "<C-s>", confirm, { buffer = bufnr, nowait = true, desc = "Save local review comment" })
	vim.keymap.set("n", "<Esc>", close_window, { buffer = bufnr, nowait = true, desc = "Cancel local review comment" })

	vim.api.nvim_win_set_cursor(winid, { vim.api.nvim_buf_line_count(bufnr), 0 })
	vim.cmd.startinsert()
end

local function next_comment_id()
	local id = "R" .. state.next_id
	state.next_id = state.next_id + 1
	return id
end

local function format_virt_text(id, comment_text)
	local lines = vim.split(comment_text, "\n", { plain = true })
	local first_line = vim.trim(lines[1] or "")

	first_line = first_line:gsub("^[>#+*%-]+%s*", "")

	local max_length = 30
	local needs_ellipsis = false

	if #first_line > max_length then
		first_line = first_line:sub(1, max_length)
		needs_ellipsis = true
	elseif #lines > 1 then
		needs_ellipsis = true
	end

	local preview = first_line
	if needs_ellipsis then
		preview = preview .. "..."
	end

	return "💬 " .. id .. ". " .. preview
end

local function session_path(root)
	return vim.fs.joinpath(root or vim.fn.getcwd(), ".local-review", "session.json")
end

local function serializable_comments()
	local comments = {}

	for _, comment in ipairs(state.comments) do
		table.insert(comments, {
			id = comment.id,
			root = comment.root,
			file = comment.file,
			line = comment.line,
			target = comment.target,
			context_before = comment.context_before,
			context_after = comment.context_after,
			comment = comment.comment,
		})
	end

	return comments
end

local function save_session()
	if not state.root or #state.comments == 0 then
		return
	end

	local path = session_path(state.root)
	local data = {
		version = 1,
		next_id = state.next_id,
		comments = serializable_comments(),
	}

	vim.fn.mkdir(vim.fs.dirname(path), "p")
	vim.fn.writefile({ vim.json.encode(data) }, path)
end

local function delete_session_file(root)
	if not root then
		return
	end

	local path = session_path(root)

	if vim.fn.filereadable(path) == 1 then
		vim.fn.delete(path)
	end
end

local function buffer_for_file(root, file)
	local path = vim.fs.joinpath(root, file)

	if vim.fn.filereadable(path) ~= 1 then
		return nil
	end

	local bufnr = vim.fn.bufadd(path)
	vim.fn.bufload(bufnr)

	return bufnr
end

local function restore_extmark(comment)
	if not comment.bufnr or not vim.api.nvim_buf_is_valid(comment.bufnr) then
		return
	end

	local line_count = vim.api.nvim_buf_line_count(comment.bufnr)
	local marker_line = math.min(math.max(comment.line, 1), line_count)

	local virt_text_label = format_virt_text(comment.id, comment.comment)
	comment.extmark_id = vim.api.nvim_buf_set_extmark(comment.bufnr, state.namespace, marker_line - 1, 0, {
		virt_text = { { virt_text_label, "DiagnosticInfo" } },
		virt_text_pos = "eol",
	})
	state.buffers[comment.bufnr] = true
end

local function load_session(root)
	local path = session_path(root)

	if vim.fn.filereadable(path) ~= 1 then
		return false
	end

	local lines = vim.fn.readfile(path)
	local ok, data = pcall(vim.json.decode, table.concat(lines, "\n"))

	if not ok or type(data) ~= "table" or type(data.comments) ~= "table" then
		vim.notify("Could not restore local review session: invalid session file", vim.log.levels.WARN)
		return false
	end

	state.root = root
	state.next_id = data.next_id or 1
	state.comments = {}
	state.buffers = {}

	for _, saved_comment in ipairs(data.comments) do
		local comment = {
			id = saved_comment.id,
			root = saved_comment.root or root,
			file = saved_comment.file,
			line = saved_comment.line,
			target = saved_comment.target,
			context_before = saved_comment.context_before or {},
			context_after = saved_comment.context_after or {},
			comment = saved_comment.comment or "",
		}

		comment.bufnr = buffer_for_file(comment.root, comment.file)
		restore_extmark(comment)
		table.insert(state.comments, comment)
	end

	return #state.comments > 0
end

local function add_comment(location, comment_text)
	local id = next_comment_id()
	local virt_text_label = format_virt_text(id, comment_text)
	local extmark_id = vim.api.nvim_buf_set_extmark(location.bufnr, state.namespace, location.line - 1, 0, {
		virt_text = { { virt_text_label, "DiagnosticInfo" } },
		virt_text_pos = "eol",
	})

	local comment = {
		id = id,
		bufnr = location.bufnr,
		extmark_id = extmark_id,
		root = location.root,
		file = location.file,
		line = location.line,
		target = location.target,
		context_before = location.context_before,
		context_after = location.context_after,
		comment = comment_text,
	}

	table.insert(state.comments, comment)
	state.buffers[location.bufnr] = true
	state.root = state.root or location.root
	save_session()

	return comment
end

local function fenced_block(label, lines)
	local content = table.concat(lines, "\n")

	if content == "" then
		return "```" .. label .. "\n```"
	end

	return "```" .. label .. "\n" .. content .. "\n```"
end

local function build_prompt()
	local lines = {
		"You are addressing a local code review.",
		"",
		"Instructions:",
		"- Address every review comment below.",
		"- Do not change unrelated code.",
		"- Preserve the existing style.",
		"- Add or update tests where appropriate.",
		"- After making changes, summarize how each comment was addressed.",
		"",
		"Review comments:",
	}

	for _, comment in ipairs(state.comments) do
		local nearby_context = vim.list_extend(vim.deepcopy(comment.context_before), { comment.target })
		vim.list_extend(nearby_context, comment.context_after)

		table.insert(lines, "")
		table.insert(lines, string.format("## %s - `%s:%d`", comment.id, comment.file, comment.line))
		table.insert(lines, "")
		table.insert(lines, "Reviewer comment:")
		table.insert(lines, "")

		for _, comment_line in ipairs(vim.split(comment.comment, "\n", { plain = true })) do
			table.insert(lines, "> " .. comment_line)
		end

		table.insert(lines, "")
		table.insert(lines, "Target code:")
		table.insert(lines, "")
		table.insert(lines, fenced_block("", { comment.target }))
		table.insert(lines, "")
		table.insert(lines, "Nearby context:")
		table.insert(lines, "")
		table.insert(lines, fenced_block("", nearby_context))
	end

	return table.concat(lines, "\n") .. "\n"
end

local function save_prompt(prompt, root)
	local dir = vim.fs.joinpath(root or vim.fn.getcwd(), ".local-review")
	local path = vim.fs.joinpath(dir, "last-review.md")

	vim.fn.mkdir(dir, "p")
	vim.fn.writefile(vim.split(prompt, "\n", { plain = true }), path)

	return path
end

local function reset_state()
	local root = state.root

	for bufnr in pairs(state.buffers) do
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_clear_namespace(bufnr, state.namespace, 0, -1)
		end
	end

	state.active = false
	state.comments = {}
	state.buffers = {}
	state.next_id = 1
	state.root = nil

	delete_session_file(root)
end

function M.setup(opts)
	config = vim.tbl_deep_extend("force", config, opts or {})

	if config.keymap then
		vim.keymap.set("n", config.keymap, M.comment, { desc = "Add local review comment" })
	end
end

function M.start()
	if state.active then
		vim.notify("Local review session already active", vim.log.levels.INFO)
		return
	end

	state.active = true
	local root = project_root_for(vim.api.nvim_buf_get_name(0))

	if load_session(root) then
		vim.notify(
			string.format("Restored local review session with %d comment(s)", #state.comments),
			vim.log.levels.INFO
		)
		return
	end

	state.root = root
	vim.notify("Local review session started", vim.log.levels.INFO)
end

function M.comment()
	if not state.active then
		M.start()
	end

	local location = capture_location()
	open_comment_window(location, function(comment)
		local stored = add_comment(location, comment)
		vim.notify(
			string.format("Stored review comment %s for %s:%d", stored.id, stored.file, stored.line),
			vim.log.levels.INFO
		)
	end)
end

function M.done()
	if not state.active then
		vim.notify("No active local review session", vim.log.levels.INFO)
		return
	end

	if #state.comments == 0 then
		reset_state()
		vim.notify("No local review comments to export", vim.log.levels.INFO)
		return
	end

	local prompt = build_prompt()
	local saved_path = save_prompt(prompt, state.comments[1].root)
	local comment_count = #state.comments

	vim.fn.setreg("+", prompt)
	reset_state()

	vim.notify(
		string.format("Copied %d review comment(s) and saved %s", comment_count, saved_path),
		vim.log.levels.INFO
	)
end

function M.status()
	local session_status = state.active and "active" or "inactive"
	local message = string.format("Local review session: %s\nComments: %d", session_status, #state.comments)
	local latest = state.comments[#state.comments]

	if latest then
		message = message .. string.format("\nLatest: %s at %s:%d", latest.id, latest.file, latest.line)
	end

	vim.notify(message, vim.log.levels.INFO)
end

function M.list()
	if #state.comments == 0 then
		vim.notify("No local review comments", vim.log.levels.INFO)
		return
	end

	local items = {}

	for _, comment in ipairs(state.comments) do
		local first_line = vim.split(comment.comment, "\n", { plain = true })[1] or ""

		table.insert(items, {
			bufnr = comment.bufnr,
			lnum = comment.line,
			col = 1,
			text = string.format("%s: %s", comment.id, first_line),
		})
	end

	vim.fn.setqflist({}, " ", {
		title = "Local Review Comments",
		items = items,
	})
	vim.cmd.copen()
end

function M.delete(id)
	id = vim.trim(id or "")

	if id == "" then
		vim.notify("LocalReviewDelete requires a comment id, for example R1", vim.log.levels.WARN)
		return
	end

	for index, comment in ipairs(state.comments) do
		if comment.id == id then
			if vim.api.nvim_buf_is_valid(comment.bufnr) then
				vim.api.nvim_buf_del_extmark(comment.bufnr, state.namespace, comment.extmark_id)
			end

			table.remove(state.comments, index)
			if #state.comments == 0 then
				delete_session_file(state.root)
			else
				save_session()
			end
			vim.notify(string.format("Deleted local review comment %s", id), vim.log.levels.INFO)
			return
		end
	end

	vim.notify(string.format("Local review comment %s not found", id), vim.log.levels.WARN)
end

function M.edit(id)
	id = vim.trim(id or "")

	if id == "" then
		vim.notify("LocalReviewEdit requires a comment id, for example R1", vim.log.levels.WARN)
		return
	end

	for _, comment in ipairs(state.comments) do
		if comment.id == id then
			open_comment_window(comment, function(updated_comment)
				comment.comment = updated_comment
				if vim.api.nvim_buf_is_valid(comment.bufnr) then
					vim.api.nvim_buf_del_extmark(comment.bufnr, state.namespace, comment.extmark_id)
					restore_extmark(comment)
				end
				save_session()
				vim.notify(string.format("Updated local review comment %s", id), vim.log.levels.INFO)
			end, comment.comment)
			return
		end
	end

	vim.notify(string.format("Local review comment %s not found", id), vim.log.levels.WARN)
end

function M.abort()
	if not state.active then
		vim.notify("No active local review session", vim.log.levels.INFO)
		return
	end

	reset_state()
	vim.notify("Local review session aborted", vim.log.levels.INFO)
end

return M
