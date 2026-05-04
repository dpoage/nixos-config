  { pkgs, ... }:                                                                                                            
   
  {                                                                                                                         
    programs.nixvim = {                                                                                                   
      enable = true;

      globals = {                                                                                                           
        mapleader = " ";
        maplocalleader = " ";                                                                                               
      };                                                                                                                  

      opts = {
        number = true;
        relativenumber = true;
        shiftwidth = 2;                                                                                                     
        tabstop = 2;
        expandtab = true;                                                                                                   
        smartindent = true;                                                                                               
        wrap = false;
        signcolumn = "yes";
        cursorline = true;                                                                                                  
        termguicolors = true;
        scrolloff = 8;                                                                                                      
        sidescrolloff = 8;                                                                                                
        updatetime = 250;
        timeoutlen = 300;                                                                                                   
        undofile = true;
        ignorecase = true;                                                                                                  
        smartcase = true;                                                                                                 
        splitbelow = true;
        splitright = true;
        clipboard = "unnamedplus";                                                                                          
        completeopt = "menu,menuone,noselect";
        showmode = false;                                                                                                   
        mouse = "a";                                                                                                      
      };                                                                                                                    
   
      colorschemes.catppuccin = {                                                                                           
        enable = true;                                                                                                    
        settings.flavour = "mocha";
      };
                                                                                                                            
      # Keymaps (LazyVim-style)
      keymaps = [                                                                                                           
        # Window navigation                                                                                               
        { mode = "n"; key = "<C-h>"; action = "<C-w>h"; options.desc = "Go to left window"; }                               
        { mode = "n"; key = "<C-j>"; action = "<C-w>j"; options.desc = "Go to lower window"; }                              
        { mode = "n"; key = "<C-k>"; action = "<C-w>k"; options.desc = "Go to upper window"; }                              
        { mode = "n"; key = "<C-l>"; action = "<C-w>l"; options.desc = "Go to right window"; }                              
                                                                                                                          
        # Buffer navigation                                                                                                 
        { mode = "n"; key = "<S-h>"; action = "<cmd>bprevious<cr>"; options.desc = "Prev buffer"; }
        { mode = "n"; key = "<S-l>"; action = "<cmd>bnext<cr>"; options.desc = "Next buffer"; }                             
        { mode = "n"; key = "<leader>bd"; action = "<cmd>bdelete<cr>"; options.desc = "Delete buffer"; }                    
                                                                                                                            
        # Clear search highlight                                                                                            
        { mode = "n"; key = "<esc>"; action = "<cmd>noh<cr><esc>"; options.desc = "Clear hlsearch"; }                       
                                                                                                                            
        # Better indenting
        { mode = "v"; key = "<"; action = "<gv"; }                                                                          
        { mode = "v"; key = ">"; action = ">gv"; }                                                                          
                                                                                                                            
        # Move lines                                                                                                        
        { mode = "n"; key = "<A-j>"; action = "<cmd>m .+1<cr>=="; options.desc = "Move down"; }                             
        { mode = "n"; key = "<A-k>"; action = "<cmd>m .-2<cr>=="; options.desc = "Move up"; }
        { mode = "v"; key = "<A-j>"; action = ":m '>+1<cr>gv=gv"; options.desc = "Move down"; }                             
        { mode = "v"; key = "<A-k>"; action = ":m '<-2<cr>gv=gv"; options.desc = "Move up"; }                               
                                                                                                                            
        # Telescope                                                                                                         
        { mode = "n"; key = "<leader>ff"; action = "<cmd>Telescope find_files<cr>"; options.desc = "Find files"; }
        { mode = "n"; key = "<leader>fg"; action = "<cmd>Telescope live_grep<cr>"; options.desc = "Live grep"; }            
        { mode = "n"; key = "<leader>fb"; action = "<cmd>Telescope buffers<cr>"; options.desc = "Buffers"; }                
        { mode = "n"; key = "<leader>fh"; action = "<cmd>Telescope help_tags<cr>"; options.desc = "Help tags"; }
        { mode = "n"; key = "<leader>fr"; action = "<cmd>Telescope oldfiles<cr>"; options.desc = "Recent files"; }          
        { mode = "n"; key = "<leader><space>"; action = "<cmd>Telescope find_files<cr>"; options.desc = "Find files"; }     
        { mode = "n"; key = "<leader>/"; action = "<cmd>Telescope live_grep<cr>"; options.desc = "Grep"; }                  
                                                                                                                            
        # Oil
        { mode = "n"; key = "-"; action = "<cmd>Oil<cr>"; options.desc = "Open parent directory"; }

        # Neo-tree
        { mode = "n"; key = "<leader>e"; action = "<cmd>Neotree toggle<cr>"; options.desc = "Toggle file explorer"; }

        # Toggleterm (Ctrl+/)
        { mode = "n"; key = "<C-/>"; action = "<cmd>ToggleTerm<cr>"; options.desc = "Toggle terminal"; }
        { mode = "t"; key = "<C-/>"; action = "<cmd>ToggleTerm<cr>"; options.desc = "Toggle terminal"; }
        { mode = "t"; key = "<Esc><Esc>"; action = "<C-\\><C-n>"; options.desc = "Exit terminal mode"; }

        # Trouble
        { mode = "n"; key = "<leader>xx"; action = "<cmd>Trouble diagnostics toggle<cr>"; options.desc = "Diagnostics"; }
        { mode = "n"; key = "<leader>xX"; action = "<cmd>Trouble diagnostics toggle filter.buf=0<cr>"; options.desc = "Buffer diagnostics"; }
        { mode = "n"; key = "<leader>xl"; action = "<cmd>Trouble loclist toggle<cr>"; options.desc = "Location list"; }
        { mode = "n"; key = "<leader>xq"; action = "<cmd>Trouble qflist toggle<cr>"; options.desc = "Quickfix list"; }

        # Undotree
        { mode = "n"; key = "<leader>u"; action = "<cmd>UndotreeToggle<cr>"; options.desc = "Toggle undotree"; }       
                                                                                                                            
        # LSP
        { mode = "n"; key = "gd"; action = "<cmd>lua vim.lsp.buf.definition()<cr>"; options.desc = "Go to definition"; }    
        { mode = "n"; key = "gr"; action = "<cmd>lua vim.lsp.buf.references()<cr>"; options.desc = "References"; }
        { mode = "n"; key = "gI"; action = "<cmd>lua vim.lsp.buf.implementation()<cr>"; options.desc = "Go to               
  implementation"; }                                                                                                        
        { mode = "n"; key = "K"; action = "<cmd>lua vim.lsp.buf.hover()<cr>"; options.desc = "Hover"; }                     
        { mode = "n"; key = "<leader>ca"; action = "<cmd>lua vim.lsp.buf.code_action()<cr>"; options.desc = "Code action"; }
        { mode = "n"; key = "<leader>cr"; action = "<cmd>lua vim.lsp.buf.rename()<cr>"; options.desc = "Rename"; }
        { mode = "n"; key = "<leader>cd"; action = "<cmd>lua vim.diagnostic.open_float()<cr>"; options.desc = "Line         
  diagnostics"; }                                                                                                           
        { mode = "n"; key = "]d"; action = "<cmd>lua vim.diagnostic.goto_next()<cr>"; options.desc = "Next diagnostic"; }   
        { mode = "n"; key = "[d"; action = "<cmd>lua vim.diagnostic.goto_prev()<cr>"; options.desc = "Prev diagnostic"; }   
      ];                                                    
                                                                                                                            
      # Plugin configurations                                                                                               
      plugins = {
        # UI                                                                                                                
        lualine.enable = true;                              
        bufferline.enable = true;
        web-devicons.enable = true;
        indent-blankline.enable = true;                                                                                     
        noice.enable = true;
        notify.enable = true;                                                                                               
        which-key.enable = true;                            
        gitsigns.enable = true;                                                                                             
        neo-tree.enable = true;
        dashboard = {                                                                                                       
          enable = true;                                    
          settings.theme = "doom";
        };                                                                                                                  
  
        # Telescope                                                                                                         
        telescope = {                                       
          enable = true;
          extensions = {
            fzf-native.enable = true;
          };                                                                                                                
        };
                                                                                                                            
        # Treesitter                                        
        treesitter = {
          enable = true;
          settings = {
            highlight.enable = true;
            indent.enable = true;
            ensure_installed = [                                                                                            
              "bash" "c" "cpp" "css" "dockerfile" "go" "gomod" "gosum"
              "html" "javascript" "json" "lua" "make" "markdown"                                                            
              "markdown_inline" "nix" "python" "query" "regex" "rust"
              "toml" "tsx" "typescript" "vim" "vimdoc" "yaml" "zig"                                                         
            ];                                                                                                              
          };                                                                                                                
        };                                                                                                                  
        treesitter-textobjects.enable = true;               

        # LSP                                                                                                               
        lsp = {
          enable = true;                                                                                                    
          servers = {                                       
            # Go
            gopls.enable = true;

            # C/C++                                                                                                         
            clangd.enable = true;
                                                                                                                            
            # Rust                                          
            rust_analyzer = {
              enable = false;
              installCargo = false;
              installRustc = false;
            };                                                                                                              
  
            # Python                                                                                                        
            pyright.enable = true;                          
            ruff.enable = true;

            # Nix                                                                                                           
            nil_ls.enable = true;
                                                                                                                            
            # Lua                                           
            lua_ls.enable = true;

            # General
            jsonls.enable = true;
            yamlls.enable = true;
            bashls.enable = true;                                                                                           
          };
        };                                                                                                                  
                                                            
        # Formatting
        conform-nvim = {
          enable = true;                                                                                                    
          settings = {
            format_on_save = {                                                                                              
              timeout_ms = 500;                             
              lsp_format = "fallback";
            };                                                                                                              
            formatters_by_ft = {
              go = [ "gofumpt" "goimports" ];                                                                               
              python = [ "ruff_format" ];                                                                                   
              rust = [ "rustfmt" ];
              cpp = [ "clang-format" ];                                                                                     
              c = [ "clang-format" ];                                                                                       
              nix = [ "nixfmt" ];
              lua = [ "stylua" ];                                                                                           
              "_" = [ "trim_whitespace" ];                  
            };                                                                                                              
          };
        };                                                                                                                  
                                                            
        # Completion
        cmp = {
          enable = true;
          settings = {
            sources = [
              { name = "nvim_lsp"; }                                                                                        
              { name = "luasnip"; }
              { name = "path"; }                                                                                            
              { name = "buffer"; }                          
            ];
            mapping = {
              "<C-n>" = "cmp.mapping.select_next_item()";
              "<C-p>" = "cmp.mapping.select_prev_item()";                                                                   
              "<C-b>" = "cmp.mapping.scroll_docs(-4)";
              "<C-f>" = "cmp.mapping.scroll_docs(4)";                                                                       
              "<C-Space>" = "cmp.mapping.complete()";       
              "<C-e>" = "cmp.mapping.abort()";                                                                              
              "<CR>" = "cmp.mapping.confirm({ select = true })";
              "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";                                          
              "<S-Tab>" = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";                                        
            };                                                                                                              
            snippet.expand = "function(args) require('luasnip').lsp_expand(args.body) end";                                 
          };                                                                                                                
        };
        cmp-nvim-lsp.enable = true;                                                                                         
        cmp-path.enable = true;                                                                                             
        cmp-buffer.enable = true;
        luasnip.enable = true;                                                                                              
        friendly-snippets.enable = true;                    
                                                                                                                            
        # Oil (file explorer as buffer)
        oil = {
          enable = true;
          settings = {
            view_options.show_hidden = true;
            skip_confirm_for_simple_edits = true;
            delete_to_trash = true;
          };
        };

        # Toggleterm (inline terminal)
        toggleterm = {
          enable = true;
          settings = {
            direction = "horizontal";
            size = 15;
            open_mapping = null;
            shade_terminals = true;
            shading_factor = 2;
          };
        };

        # Trouble (structured diagnostics)
        trouble.enable = true;

        # Fidget (LSP progress)
        fidget.enable = true;

        # Illuminate (highlight word under cursor)
        illuminate.enable = true;

        # Undotree
        undotree.enable = true;

        # Telescope UI select
        telescope.extensions.ui-select.enable = true;

        # Editing
        mini = {                                                                                                            
          enable = true;                                    
          modules = {
            pairs = {};
            surround = {};
            comment = {};                                                                                                   
          };
        };                                                                                                                  
        todo-comments.enable = true;                        
        flash.enable = true;

        # Language extras                                                                                                   
        rustaceanvim.enable = true;
      };                                                                                                                    
                                                            
      # Extra packages for formatters                                                                                       
      extraPackages = with pkgs; [
        gofumpt                                                                                                             
        gotools                                             
        nixfmt-rfc-style
        stylua
      ];
    };                                                                                                                      
  }


