// SPDX-License-Identifier: GPL-2.0
#include <linux/module.h>
#include <linux/pci.h>

#define INNODISK_VID 0x1bc0
#define INNODISK_3TE6_DID 0x1002

static void set_no_d3(bool on)
{
	struct pci_dev *pdev = NULL;

	while ((pdev = pci_get_device(INNODISK_VID, INNODISK_3TE6_DID, pdev))) {
		if (on)
			pdev->dev_flags |= PCI_DEV_FLAGS_NO_D3;
		else
			pdev->dev_flags &= ~PCI_DEV_FLAGS_NO_D3;
		pci_info(pdev, "D3 %s\n", on ? "disabled" : "re-enabled");
	}
}

static int __init innodisk_no_d3_init(void)
{
	set_no_d3(true);
	return 0;
}

static void __exit innodisk_no_d3_exit(void)
{
	set_no_d3(false);
}

module_init(innodisk_no_d3_init);
module_exit(innodisk_no_d3_exit);
MODULE_DESCRIPTION("Keep Innodisk 3TE6 NVMe in D0 across system suspend");
MODULE_LICENSE("GPL");
