 # tiny.asm
  
  
        .byte      0x7F, 'E','L','F'             # e_ident
        .long      1                                       # p_type
        .long      0                                       # p_offset
        .long       0x8048000
        .short      2                       # e_type        # p_pa.longr
        .short      3                       # e_machine
        .long      _start                  # e_version     # p_filesz
        .long      _start                  # e_entry       # p_memsz
        .long      4                       # e_phoff       # p_flags
  _start:
        mov     $42,%bl                   # e_shoff       # p_align
        xor     %eax, %eax
        inc     %eax                     # e_flags
        int     $0x80
        .byte      0
        .short      0x34                    # e_ehsize
        .short      0x20                    # e_phentsize
        .byte      1                       # e_phnum
                                                # e_shentsize
                                                # e_shnum
                                                # e_shstrndx
  
