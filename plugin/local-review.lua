vim.api.nvim_create_user_command("LocalReviewStart", function()
	require("local_review").start()
end, {})

vim.api.nvim_create_user_command("LocalReviewComment", function()
	require("local_review").comment()
end, {})

vim.api.nvim_create_user_command("LocalReviewDone", function()
	require("local_review").done()
end, {})

vim.api.nvim_create_user_command("LocalReviewAbort", function()
	require("local_review").abort()
end, {})

vim.api.nvim_create_user_command("LocalReviewStatus", function()
	require("local_review").status()
end, {})

vim.api.nvim_create_user_command("LocalReviewList", function()
	require("local_review").list()
end, {})

vim.api.nvim_create_user_command("LocalReviewDelete", function(opts)
	require("local_review").delete(opts.args)
end, {
	nargs = 1,
})
