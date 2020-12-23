#include <unistd.h>
#include <sys/reboot.h>

main()
{
  sync();
  reboot(RB_AUTOBOOT);
}
