#include <linux/module.h>
#include <linux/slab.h>
#include <linux/init.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("David Korenchuk");

#define OBJ_COUNT 32

struct cache_entry {
	int dummy[4];
};

static struct kmem_cache *cache;
static void *objects[OBJ_COUNT];

/* This works when all allocated data is located in one page.
 *
 * Then just page map is printed. But when several pages
 * are allocated, this function will not work.
 */
static void print_address_map(void **objs, int count, size_t obj_size)
{
	unsigned long base = (u64) objs[0];
	unsigned long max_addr = base;
	int i;
	
	for (i = 0; i < count; i++) {
		if (objs[i] && (u64) objs[i] > max_addr)
			max_addr = (u64) objs[i];
	}
	
	for (i = 0; i < count; i++) {
		if (objs[i] && (u64) objs[i] < base)
			base = (u64) objs[i];
	}

	unsigned long range = max_addr - base + obj_size;
	pr_info("base:  0x%lx", base);
	pr_info("max:   0x%lx", max_addr);
	pr_info("range: 0x%lx", range);
	int cells = range / obj_size + 1;
	char *map = kmalloc(cells + 1, GFP_KERNEL);
	if (!map) {
		pr_err("print_address_map_ascii: no memory\n");
		return;
	}
	
	memset(map, '.', cells);
	map[cells] = '\0';
	
	for (i = 0; i < count; i++) {
		if (objs[i]) {
			int pos = ((u64) objs[i] - base) / obj_size;
			if (pos >= 0 && pos < cells)
				map[pos] = 'X';
		}
	}
	
	pr_info("Memory fragmentation map (base=0x%lx, obj_size=%zu, range=%lu, cells=%d):\n",
		base, obj_size, range, cells);
	
	for (i = 0; i < cells; i += 32) {
		int line_len = (i + 32 <= cells) ? 32 : (cells - i);
	
		char buf[33];
		memcpy(buf, &map[i], line_len);
		buf[line_len] = '\0';
		pr_info("0x%016lx: %s\n", base + i * obj_size, buf);
	}
	
	kfree(map);
}

__init static int study_slab_fragmentation_dump_init(void)
{
	int i;
	
	cache = kmem_cache_create("frag_addr_cache", sizeof(struct cache_entry), 0, SLAB_HWCACHE_ALIGN, NULL);
	if (!cache)
		return -ENOMEM;
	
	for (i = 0; i < OBJ_COUNT; i++) {
		objects[i] = kmem_cache_alloc(cache, GFP_KERNEL);
		pr_info("Allocated 0x%llx 0x%lx", (u64) objects[i], __phys_addr((u64) objects[i]));
	}
	
	print_address_map(objects, OBJ_COUNT, sizeof(struct cache_entry));
	
	return 0;
}

__exit static void study_slab_fragmentation_dump_exit(void)
{
	int i;
	for (i = 0; i < OBJ_COUNT; i++)
		if (objects[i])
			kmem_cache_free(cache, objects[i]);
	
	kmem_cache_destroy(cache);
}

module_init(study_slab_fragmentation_dump_init);
module_exit(study_slab_fragmentation_dump_exit);
