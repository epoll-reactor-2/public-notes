#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/rbtree.h>
#include <linux/slab.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("David Korenchuk");

struct rb_element_node {
	int key;
	struct rb_node rb;
};

static struct rb_root global_rb_tree = RB_ROOT;

static int add(int key)
{
	struct rb_node **new = &global_rb_tree.rb_node;
	struct rb_node *parent = NULL;

	while (*new) {
		struct rb_element_node *this = rb_entry(*new, struct rb_element_node, rb);
		parent = *new;
		if (key < this->key)
			new = &((*new)->rb_left);
		else if (key > this->key)
			new = &((*new)->rb_right);
		else
			return -EEXIST;
	}

	struct rb_element_node *node = kzalloc(sizeof(*node), GFP_KERNEL);
	if (!node)
		return -ENOMEM;
	node->key = key;
	rb_link_node(&node->rb, parent, new);
	rb_insert_color(&node->rb, &global_rb_tree);
	return 0;
}


static void walk_inorder(struct rb_node *node, int depth)
{
	if (!node)
		return;

	walk_inorder(node->rb_left, depth + 1);
	for (u64 i = 0; i < (5 - depth); ++i)
		pr_cont("____");

	struct rb_element_node *e = rb_entry(node, struct rb_element_node, rb);
	pr_cont("%d\n", e->key);
	walk_inorder(node->rb_right, depth + 1);
}


__init static int study_rbtree_init(void)
{
	int input[] = { 5, 1, 9, 3, 4, 5, 0, 27, 71, 100, 200 };
	u64 i;

	for (i = 0; i < ARRAY_SIZE(input); ++i)
		if (add(input[i]) < 0)
			pr_info("Failed to add");

	pr_info("Pretty-printed RB tree:\n");
	walk_inorder(global_rb_tree.rb_node, 0);

	return 0;
}

__exit static void study_rbtree_exit(void)
{

}

module_init(study_rbtree_init);
module_exit(study_rbtree_exit);

