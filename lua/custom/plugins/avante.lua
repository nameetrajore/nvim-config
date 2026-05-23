vim.pack.add {
  'https://github.com/MunifTanjim/nui.nvim',
  'https://github.com/stevearc/dressing.nvim',
  'https://github.com/HakonHarnes/img-clip.nvim',
  'https://github.com/MeanderingProgrammer/render-markdown.nvim',
  'https://github.com/yetone/avante.nvim',
}

require('img-clip').setup {
  default = {
    embed_image_as_base64 = false,
    prompt_for_file_name = false,
    drag_and_drop = { insert_mode = true },
    use_absolute_path = true,
  },
}

require('render-markdown').setup {
  file_types = { 'markdown', 'Avante' },
}

require('avante').setup {
  instructions_file = 'avante.md',
  provider = 'claude',
  providers = {
    claude = {
      endpoint = 'https://api.anthropic.com',
      model = 'claude-sonnet-4-6',
      timeout = 30000,
      extra_request_body = {
        temperature = 0.75,
        max_tokens = 20480,
      },
    },
    moonshot = {
      endpoint = 'https://api.moonshot.ai/v1',
      model = 'kimi-k2-0711-preview',
      timeout = 30000,
      extra_request_body = {
        temperature = 0.75,
        max_tokens = 32768,
      },
    },
  },
}
