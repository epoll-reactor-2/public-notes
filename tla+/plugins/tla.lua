return {
  "susliko/tla.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function ()
    -- Setup tla.nvim
    require("tla").setup({
      java_executable   = "/usr/lib/jvm/java-21-openjdk-amd64/bin/java",
      java_opts         = { "-Xmx4g", "-DTLA-Library=/opt/tla/lib/tlaps" },
      tla2tools         = "/opt/tla/tla2tools.jar"
    })

    local function open_scratch_buffer(lines, filetype)
      vim.cmd("vnew")
      local buf = vim.api.nvim_get_current_buf()
      local win = vim.api.nvim_get_current_win()

      -- Configure as scratch buffer
      vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
      vim.api.nvim_buf_set_option(buf, "swapfile", false)
      vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
      vim.api.nvim_win_set_option(win, "wrap", true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.api.nvim_buf_set_option(buf, "modifiable", false)

      if filetype then
        vim.api.nvim_buf_set_option(buf, "filetype", filetype)
      end
    end

    -- Define custom commands using the helper
    vim.api.nvim_create_user_command("TlaPdf", function()
      local filename = vim.fn.expand("%:p")
      local texname = vim.fn.expand("%:t:r") .. ".tex"
      local cmd = string.format(
        "/usr/lib/jvm/java-21-openjdk-amd64/bin/java -Xmx4g -DTLA-Library=/opt/tla/lib/tlaps -cp /opt/tla/tla2tools.jar tla2tex.TLA -shade %q && pdflatex %q",
        filename,
        texname
      )
      vim.fn.systemlist(cmd)
      print("PDF for " .. vim.fn.expand("%:t") .. " generated")
    end, {})

    vim.api.nvim_create_user_command("TlaProof", function()
      local filename = vim.fn.expand("%:p")
      local cmd = string.format("/opt/tla/bin/tlapm %q", filename)
      local output = vim.fn.systemlist(cmd)
      open_scratch_buffer(output, "tla")
    end, {})
  end
}
