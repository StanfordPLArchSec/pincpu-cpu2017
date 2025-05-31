from elftools.elf.elffile import ELFFile
import capstone

class Disassembler:
    def __init__(self, exe_path):
        f = open(exe_path, "rb")
        elf = ELFFile(f)
        self.text = elf.get_section_by_name(".text")
        self.text_addr = self.text["sh_addr"]
        self.text_offset = self.text["sh_offset"]
        self.text_data = self.text.data()
        self.md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_64)

    def disasm(self, addr):
        assert type(addr) is int
        offset = addr - self.text_addr
        if 0 <= offset < len(self.text_data):
            code = self.text_data[offset : offset + 16]
            return next(self.md.disasm(code, addr), None)
        else:
            return None

    def opcode(self, addr):
        if inst := self.disasm(addr):
            return inst.mnemonic
        return None
