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
