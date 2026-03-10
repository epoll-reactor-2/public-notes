/*
 * list.c - Linked list usage.
 */
#include <linux/kernel.h>
#include <linux/module.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("David Korenchuk");

struct ll_node {
        int data;
        struct list_head list;
};

/* Note that all code is unmapped from the kernel
 * address space when module is exited. */
static LIST_HEAD(global_llist);

__init static int study_llist_init(void)
{
        struct ll_node *node = NULL;
        u64 i;
        u64 total = 5;

        for (i = 0; i < total; ++i) {
                node = kzalloc(sizeof (*node), GFP_KERNEL);
                if (!node)
                        return -ENOMEM;
                node->data = i;
                INIT_LIST_HEAD(&node->list);
                list_add_tail(&node->list, &global_llist);
        }

        pr_info("llist created:");
        list_for_each_entry(node, &global_llist, list) {
                pr_info("Element: %d", node->data);
        }

        pr_info("list module initialized");
        return 0;
}

__exit static void study_llist_exit(void)
{
        struct ll_node *node = NULL;
        struct ll_node *safe = NULL;

        list_for_each_entry_safe(node, safe, &global_llist, list) {
                pr_info("Freeing: %d", node->data);
                list_del(&node->list);
                kfree(node);
        }

        pr_info("list module exited");
}

module_init(study_llist_init);
module_exit(study_llist_exit);
