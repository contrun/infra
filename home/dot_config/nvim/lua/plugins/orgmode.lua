require('orgmode').setup({
  org_agenda_files = { '~/Sync/docs/org-mode/**/*.org' },
  org_default_notes_file = '~/Sync/docs/org-mode/refile.org'
})

require 'cmp'.setup({ sources = { { name = 'orgmode' } } })
