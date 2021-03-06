
if [ "$ROCKCFG_X86_BITS" = 32 ] ; then
  case "$ROCKCFG_X86_OPT" in
    i?86)
	arch_machine="$ROCKCFG_X86_OPT" ;;

    pentium|pentium-mmx|k6*)
	arch_machine="i586" ;;

    pentium*|athlon*)
	arch_machine="i686" ;;
  esac
else
  arch_sizeof_long=8
  arch_sizeof_char_p=8
  arch_machine="x86_64"
  arch_target32="i686-pc-linux-gnu"
  BUILD32="-m32"
  BUILD64="-m64"
fi

arch_target="${arch_machine}-unknown-linux-gnu"

if [ "$ROCKCFG_X86_BITS" = 64 ] ; then
	arch_target64="$arch_target"
fi
