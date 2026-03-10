#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/bitmap.h>
#include <linux/bitops.h>
#include <linux/init.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("David Korenchuk");

#define BITS_NUM 64

static unsigned long global_bitmap[BITS_TO_LONGS(BITS_NUM)];

__init static int study_bitmap_init(void)
{
	int i;
	int first_zero;

	bitmap_zero(global_bitmap, BITS_NUM);
	bitmap_set(global_bitmap, 2, 1);
	bitmap_set(global_bitmap, 5, 1);
	bitmap_set(global_bitmap, 9, 1);

	for (i = 0; i < 16; ++i)
		pr_info("bit %02d = %d", i, test_bit(i, global_bitmap));

	first_zero = bitmap_find_next_zero_area(global_bitmap, BITS_NUM, 0, 1, 0);
	pr_info("first zero bit: %d", first_zero);

	bitmap_clear(global_bitmap, 5, 1);
	pr_info("bit 5 is reset");
	pr_info("bit 5 after reset: %d", test_bit(1, global_bitmap));
	pr_info("");

	return 0;
}

__exit static void study_bitmap_exit(void)
{
}

module_init(study_bitmap_init);
module_exit(study_bitmap_exit);
