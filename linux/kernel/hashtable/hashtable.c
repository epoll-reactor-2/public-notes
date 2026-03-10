#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/slab.h>
#include <linux/hashtable.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("David Korenchuk");

struct hmap_node {
	int key;
	int value;
	struct hlist_node hnode;
};

/* Hash key size is 4 bits (16 buckets). */
DEFINE_HASHTABLE(global_htable, 4);

__init static int study_hmap_init(void)
{
	struct hmap_node *node = NULL;
	u64 i;
	int rc = 0;

	for (i = 0; i < 5; ++i) {
		node = kzalloc(sizeof(*node), GFP_KERNEL);
		if (!node) {
			rc = -ENOMEM;
			goto exit;
		}

		node->key = i;
		node->value = i * 10;
		hash_add(global_htable, &node->hnode, node->key);
		pr_info("Added entry, key=%d, value=%d", node->key, node->value);
	}

	hash_for_each_possible(global_htable, node, hnode, 5) {
		if (node->key == 5) {
			pr_info("Found entry with key=%d: %d", 5, node->value);
			break;
		}
	}

exit:
	pr_info("hmap module initialized");
	return rc;
}

__exit static void study_hmap_exit(void)
{
	struct hmap_node *node = NULL;
	struct hlist_node *safe = NULL;
	int bkt;

	hash_for_each_safe(global_htable, bkt, safe, node, hnode) {
		pr_info("Remove entry, key=%d, value=%d", node->key, node->value);
		hash_del(&node->hnode);
		kfree(node);
	}

	pr_info("hmap module exited");
}

module_init(study_hmap_init);
module_exit(study_hmap_exit);
