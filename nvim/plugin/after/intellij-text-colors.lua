-- IntelliJ/Darcula-style text colors for Neovim.
--
-- Rollback baseline before this file was added:
-- - Colorscheme: aether, configured by lua/plugins/theme.lua
-- - Normal foreground: #fadad1
-- - Editor background: #000000, configured by plugin/after/transparency.lua
--
-- To roll back the text colors only, delete this file or move it out of
-- ~/.config/nvim/plugin/after/, then restart Neovim or run:
--   :colorscheme aether
--   :luafile ~/.config/nvim/plugin/after/transparency.lua

local colors = {
	default = "#E6E6E6",
	comment = "#6A8759",
	keyword = "#EBA055",
	string = "#90C35A",
	number = "#6897BB",
	function_name = "#56A8F5",
	field = "#E6E6E6",
	type = "#79D7FF",
	builtin_type = "#EBA055",
	namespace = "#C7D36F",
	annotation = "#BBB529",
	error = "#BC3F3C",
}

local groups = {
	Normal = colors.default,
	Identifier = colors.field,
	Statement = colors.keyword,
	Keyword = colors.keyword,
	Conditional = colors.keyword,
	Repeat = colors.keyword,
	Exception = colors.keyword,
	Operator = colors.keyword,
	String = colors.string,
	Character = colors.string,
	Number = colors.number,
	Float = colors.number,
	Boolean = colors.keyword,
	Function = colors.function_name,
	Type = colors.type,
	StorageClass = colors.keyword,
	Structure = colors.type,
	Typedef = colors.type,
	Constant = colors.default,
	Special = colors.annotation,
	PreProc = colors.annotation,
	Include = colors.keyword,
	Define = colors.keyword,
	Macro = colors.annotation,
	Comment = colors.comment,
	DiagnosticError = colors.error,
	DiagnosticWarn = colors.annotation,
	DiagnosticInfo = colors.number,
	DiagnosticHint = colors.comment,

	["@variable"] = colors.field,
	["@variable.builtin"] = colors.keyword,
	["@variable.parameter"] = colors.field,
	["@variable.member"] = colors.field,
	["@property"] = colors.field,
	["@field"] = colors.field,
	["@constant"] = colors.field,
	["@constant.builtin"] = colors.keyword,
	["@string"] = colors.string,
	["@character"] = colors.string,
	["@number"] = colors.number,
	["@float"] = colors.number,
	["@boolean"] = colors.keyword,
	["@function"] = colors.function_name,
	["@function.call"] = colors.function_name,
	["@function.builtin"] = colors.function_name,
	["@function.method"] = colors.function_name,
	["@function.method.call"] = colors.function_name,
	["@method"] = colors.function_name,
	["@method.call"] = colors.function_name,
	["@constructor"] = colors.function_name,
	["@keyword"] = colors.keyword,
	["@keyword.function"] = colors.keyword,
	["@keyword.operator"] = colors.keyword,
	["@conditional"] = colors.keyword,
	["@repeat"] = colors.keyword,
	["@exception"] = colors.keyword,
	["@operator"] = colors.keyword,
	["@type"] = colors.type,
	["@type.builtin"] = colors.builtin_type,
	["@type.definition"] = colors.type,
	["@namespace"] = colors.namespace,
	["@module"] = colors.namespace,
	["@attribute"] = colors.annotation,
	["@comment"] = colors.comment,
	["@lsp.type.function"] = colors.function_name,
	["@lsp.type.method"] = colors.function_name,
	["@lsp.type.type"] = colors.type,
	["@lsp.type.class"] = colors.type,
	["@lsp.type.interface"] = colors.type,
	["@lsp.type.struct"] = colors.type,
	["@lsp.type.enum"] = colors.type,
	["@lsp.type.typeParameter"] = colors.type,
	["@lsp.type.namespace"] = colors.namespace,
	["@lsp.type.package"] = colors.namespace,
	["@lsp.type.module"] = colors.namespace,
	["@lsp.type.variable"] = colors.field,
	["@lsp.type.property"] = colors.field,
	["@lsp.type.field"] = colors.field,
	["@lsp.type.parameter"] = colors.field,
	["@lsp.type.enumMember"] = colors.field,
	["@lsp.typemod.type.defaultLibrary"] = colors.builtin_type,
	["@lsp.typemod.class.defaultLibrary"] = colors.builtin_type,
	["@lsp.typemod.interface.defaultLibrary"] = colors.builtin_type,
	["@lsp.typemod.function.declaration"] = colors.function_name,
	["@lsp.typemod.method.declaration"] = colors.function_name,
	["@lsp.typemod.variable.declaration"] = colors.field,
	["@lsp.typemod.property.declaration"] = colors.field,
	["@lsp.typemod.field.declaration"] = colors.field,
}

local language_suffixes = {
	"bash",
	"c",
	"cpp",
	"css",
	"go",
	"html",
	"java",
	"javascript",
	"json",
	"lua",
	"python",
	"rust",
	"tsx",
	"typescript",
	"vim",
	"yaml",
}

local language_scoped_groups = {
	["@variable"] = colors.field,
	["@variable.parameter"] = colors.field,
	["@variable.member"] = colors.field,
	["@property"] = colors.field,
	["@field"] = colors.field,
	["@constant"] = colors.field,
	["@function"] = colors.function_name,
	["@function.call"] = colors.function_name,
	["@function.method"] = colors.function_name,
	["@function.method.call"] = colors.function_name,
	["@method"] = colors.function_name,
	["@method.call"] = colors.function_name,
	["@constructor"] = colors.function_name,
	["@keyword"] = colors.keyword,
	["@keyword.function"] = colors.keyword,
	["@keyword.operator"] = colors.keyword,
	["@keyword.return"] = colors.keyword,
	["@keyword.import"] = colors.keyword,
	["@string"] = colors.string,
	["@number"] = colors.number,
	["@float"] = colors.number,
	["@boolean"] = colors.keyword,
	["@comment"] = colors.comment,
	["@type"] = colors.type,
	["@type.builtin"] = colors.builtin_type,
	["@type.definition"] = colors.type,
	["@namespace"] = colors.namespace,
	["@module"] = colors.namespace,
	["@lsp.type.function"] = colors.function_name,
	["@lsp.type.method"] = colors.function_name,
	["@lsp.type.type"] = colors.type,
	["@lsp.type.class"] = colors.type,
	["@lsp.type.interface"] = colors.type,
	["@lsp.type.struct"] = colors.type,
	["@lsp.type.enum"] = colors.type,
	["@lsp.type.typeParameter"] = colors.type,
	["@lsp.type.namespace"] = colors.namespace,
	["@lsp.type.package"] = colors.namespace,
	["@lsp.type.module"] = colors.namespace,
	["@lsp.type.variable"] = colors.field,
	["@lsp.type.property"] = colors.field,
	["@lsp.type.field"] = colors.field,
	["@lsp.type.parameter"] = colors.field,
	["@lsp.type.enumMember"] = colors.field,
	["@lsp.typemod.type.defaultLibrary"] = colors.builtin_type,
	["@lsp.typemod.class.defaultLibrary"] = colors.builtin_type,
	["@lsp.typemod.interface.defaultLibrary"] = colors.builtin_type,
	["@lsp.typemod.function.declaration"] = colors.function_name,
	["@lsp.typemod.method.declaration"] = colors.function_name,
	["@lsp.typemod.variable.declaration"] = colors.field,
	["@lsp.typemod.property.declaration"] = colors.field,
	["@lsp.typemod.field.declaration"] = colors.field,
}

local function set_foreground(name, fg)
	local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
	if not ok then
		return
	end

	hl.fg = fg
	vim.api.nvim_set_hl(0, name, hl)
end

local function apply()
	for name, fg in pairs(groups) do
		set_foreground(name, fg)
	end

	for name, fg in pairs(language_scoped_groups) do
		for _, suffix in ipairs(language_suffixes) do
			set_foreground(name .. "." .. suffix, fg)
		end
	end

	-- Keep the editor background true black even if a colorscheme reloads.
	for _, name in ipairs({ "Normal", "NormalNC" }) do
		local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
		if ok then
			hl.bg = "#000000"
			vim.api.nvim_set_hl(0, name, hl)
		end
	end
end

local group = vim.api.nvim_create_augroup("UserIntellijTextColors", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
	group = group,
	callback = apply,
})

apply()
