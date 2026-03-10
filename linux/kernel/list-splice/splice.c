// SPDX-License-Identifier: GPL-2.0
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/slab.h>
#include <linux/list.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("David Korenchuk");

struct ll_node {
	int data;
	struct list_head list;
};

static LIST_HEAD(global_llist_1);
static LIST_HEAD(global_llist_2);

static int add(struct list_head *l, int value)
{
	struct ll_node *node = NULL;

	node = kzalloc(sizeof(*node), GFP_KERNEL);
	if (!node)
		return -ENOMEM;

	node->data = value;
	INIT_LIST_HEAD(&node->list);
	list_add_tail(&node->list, l);

	return 0;
}

__init static int study_llist_init(void)
{
        struct ll_node *node = NULL;
        u64 i;
        u64 total = 5;
	int rc = 0;

        for (i = 0; i < total; ++i) {
		rc = add(&global_llist_1, i);
		if (rc < 0)
			goto exit;
	}

        for (i = total; i < total + 3; ++i) {
		rc = add(&global_llist_2, i);
		if (rc < 0)
			goto exit;
        }

        pr_info("llist_1 before splice:");
        list_for_each_entry(node, &global_llist_1, list) {
                pr_info("Element: %d", node->data);
        }

        pr_info("llist_2 before splice:");
        list_for_each_entry(node, &global_llist_2, list) {
                pr_info("Element: %d", node->data);
        }

        /* Splice another_llist at the tail of global_llist */
        list_splice_tail_init(&global_llist_2, &global_llist_1);

        pr_info("llist_1 after splice:");
        list_for_each_entry(node, &global_llist_1, list) {
                pr_info("Element: %d", node->data);
        }

        pr_info("llist_2 after splice (expected to be empty):");
        list_for_each_entry(node, &global_llist_2, list) {
                pr_info("Element: %d", node->data);
        }

exit:
        pr_info("list module initialized");
        return rc;
}

__exit static void study_llist_exit(void)
{
        struct ll_node *node = NULL;
        struct ll_node *safe = NULL;

        list_for_each_entry_safe(node, safe, &global_llist_1, list) {
                pr_info("Freeing: %d", node->data);
                list_del(&node->list);
                kfree(node);
        }

        pr_info("list module exited");
}

module_init(study_llist_init);
module_exit(study_llist_exit);
