module mordor.common.containers.redblacktree;

int defaultCmp(T)(ref T lhs, ref T rhs)
{
    static if (is(typeof(lhs.opCmp(rhs)))) {
        return lhs.opCmp(rhs);
    } else static if (is(typeof(lhs - rhs) : int)) {
        return lhs - rhs;
    } else static if (is(typeof(lhs < rhs))) {
        if (lhs < rhs)
            return -1;
        else if (rhs < lhs)
            return 1;
        else
            return 0;
    } else {
        static assert(false, "No comparison operator defined");
    }
}

class RedBlackTree(T, alias cmp = defaultCmp!(T), bool includeSize = true)
{
protected:
    enum Color
    {
        Red,
        Black
    }
    struct Node
    {
        Color color;
        Node* left;
        Node* right;
        Node* parent;
        T val;
    }
    struct Leaf
    {
        Color color = Color.Black;
    }
    
public:
    static struct Iterator
    {
    public:
        T val() { return _node.val; }

        Iterator opPostInc()
        {
            Node* node = _node;
            _node = next(_node);
            return Iterator(node);
        }

        Iterator opPostDec()
        {
            Node* node = _node;
            _node = prev(_node);
            return Iterator(node);
        }

        Iterator opAdd(ptrdiff_t delta)
        {
            Node* node = _node;
            while(delta > 0) {
                node = next(node);
                --delta;
            }
            while(delta < 0) {
                node = prev(node);
                ++delta;
            }
            return Iterator(node);
        }

        Iterator opSub(ptrdiff_t delta)
        {
            Node* node = _node;
            while(delta > 0) {
                node = prev(node);
                --delta;
            }
            while(delta < 0) {
                node = next(node);
                ++delta;
            }
            return Iterator(node);
        }

        Iterator opAddAssign(ptrdiff_t delta)
        {
            while(delta > 0) {
                _node = next(_node);
                --delta;
            }
            while(delta < 0) {
                _node = prev(_node);
                ++delta;
            }
            return *this;
        }

        Iterator opSubAssign(ptrdiff_t delta)
        {
            while(delta > 0) {
                _node = prev(_node);
                --delta;
            }
            while(delta < 0) {
                _node = next(_node);
                ++delta;
            }
            return *this;
        }

    private:
        Node* next(Node* node)
        {
            assert(node != leaf);
            if (node.right != leaf)
                return depthLeft(node.right);

            while (true) {
                if (node.parent is null)
                    return leaf;
                if (node.parent.left == node)
                    return node.parent;
                node = node.parent;
            }
        }
        Node* prev(Node* prev)
        {
            assert(false);
        }
        
    private:
        Node* _node;
    }

public:
    this()
    {
        root = leaf;
    }
    
    Iterator begin() { return Iterator(depthLeft(root)); }
    Iterator end() { return Iterator(leaf); }
    
    void insert(T v)
    {
        Node* parent = null;
        Node* node = root;
        int result;
        while (node != leaf) {
            parent = node;
            result = cmp(v, node.val);
            if (result == 0) {
                // cmp may not be exact equality
                node.val = v;
                return;
            } else if (result < 0) {
                node = node.left;
            } else {
                node = node.right;
            }
        }
        
        node = new Node;
        *node = Node(Color.Red, leaf, leaf, parent, v);
        
        if (node.parent is null) {
            root = node;
        } else if (result < 0) {
            parent.left = node;
        } else {
            parent.right = node;
        }
        
        while (true)
        {
            if (node.parent is null) {
                node.color = Color.Black;
                break;
            }
    
            if (node.parent.color == Color.Black) {
                break;
            }

            Node* grandparent = grandparent(node);
            if (/* node.parent.color == Color.Red && */ uncle(node).color == Color.Red) {
                node.parent.color = Color.Black;
                uncle(node).color = Color.Black;
                grandparent.color = Color.Red;
                node = grandparent;
                continue;
            }
            
            if (node == node.parent.right && node.parent == grandparent.left) {
                rotateLeft(node.parent);
                node = node.left;
            } else if (node == node.parent.left && node.parent == grandparent.right) {
                rotateRight(node.parent);
                node = node.right;
            }
            
            node.parent.color = Color.Black;
            grandparent = this.grandparent(node);
            grandparent.color = Color.Red;
            if (node == node.parent.left && node.parent == grandparent.left) {
                rotateRight(grandparent);
            } else {
                rotateLeft(grandparent);
            }
            break;
        }
    }
    
    Iterator find(T v)
    {
        Node* node = root;
        int result;
        while (node != leaf) {
            result = cmp(v, node.val);
            if (result == 0) {
                return Iterator(node);
            } else if (result < 0) {
                node = node.left;
            } else {
                node = node.right;
            }
        }
        return end;
    }
    
    // void erase(Iterator it)
    
    void clear()
    {
        root = leaf;
    }
    
    bool empty()
    {
        return root == leaf;
    }
    
    int opApply(int delegate(ref T) dg)
    {
        int ret;
        for(Iterator it = begin; it != end; ++it) {
            T val = it.val;
            if ( (ret = dg(val)) != 0) return ret;
        }
        return 0;
    }

private:
    static Node* grandparent(Node* node)
    {
        if (node !is null && node.parent !is null)
            return node.parent.parent;
        return null;
    }
    static Node* uncle(Node* node)
    {
        Node* grandparent = grandparent(node);
        if (grandparent is null)
            return null;
        if (node.parent == grandparent.left)
            return grandparent.right;
        else
            return grandparent.left;
    }
    
    void rotateLeft(Node* node)
    {
        if (node.parent !is null) {
            if (node.parent.left == node)
                node.parent.left = node.right;
            else
                node.parent.right = node.right;
        } else {
            root = node.right;
        }
        node.right.parent = node.parent;
        node.parent = node.right;
        node.right = node.right.left;
        if (node.right != leaf)
            node.right.parent = node;
        node.parent.left = node;        
    }
    
    void rotateRight(Node* node)
    {
        if (node.parent !is null) {
            if (node.parent.left == node)
                node.parent.left = node.left;
            else
                node.parent.right = node.left;
        } else {
            root = node.left;
        }
        node.left.parent = node.parent;
        node.parent = node.left;
        node.left = node.left.right;
        if (node.left != leaf)
            node.left.parent = node;
        node.parent.right = node;
    }
    
    static Node* depthLeft(Node* node)
    {
        if (node == leaf)
            return node;
        while (node.left != leaf)
            node = node.left;
        return node;            
    }
    
protected:
    Node* root;
    static Node* leaf() { return cast(Node*)&_leaf; }

private:
    static const Leaf _leaf;

    invariant()
    {
        assert(root.color == Color.Black);
        
        size_t countBlack(Node* node) {
            if (node.color == Color.Red) {
                assert(node.left.color == Color.Black);
                assert(node.right.color == Color.Black);
            }

            if (node == leaf)
                return 1;

            if (node.left != leaf)
                assert(cmp(node.left.val, node.val) < 0);
            if (node.right != leaf)
                assert(cmp(node.right.val, node.val) > 0);

            size_t leftCount = countBlack(node.left);
            size_t rightCount = countBlack(node.right);
            assert(leftCount == rightCount);
            if (node.color == Color.Black)
                return leftCount + 1;
            return leftCount;
        }
            
        countBlack(root);
    }
}

//import tango.core.Exception;
//import tango.io.Stdout;

private void isEqualTree(T)(RedBlackTree!(T) actual, T[] expected)
{
  if (expected.length == 0) {
      assert(actual.empty);
      assert(actual.begin == actual.end);
      return;
  }
  
  auto it = actual.begin;
  foreach(v; expected) {
      assert(it != actual.end);
      assert(it.val == v);
      ++it;
  }
  assert(it == actual.end);
}

/+
private void dumpTree(T)(RedBlackTree!(T) tree)
{
  static void dumpNode(RedBlackTree!(T).Node* node)
  {
      if (node == RedBlackTree!(T).leaf)
          return;
      Stdout.formatln("Node {} ({}) is {}, left child: {}, right child: {}, parent: {}",
          cast(void*)node, node.val, node.color, cast(void*)node.left, cast(void*)node.right,
          cast(void*)node.parent);
      dumpNode(node.left);
      dumpNode(node.right);
  }
  dumpNode(tree.root);
}
+/

unittest
{
  RedBlackTree!(int) tree = new RedBlackTree!(int)();
  isEqualTree(tree, cast(int[])[]);
  tree.insert(13);
  isEqualTree(tree, [13]);
  
  tree.insert(1);
  isEqualTree(tree, [1, 13]);
  
  tree.insert(8);
  isEqualTree(tree, [1, 8, 13]);
  
  tree.insert(11);
  isEqualTree(tree, [1, 8, 11, 13]);
  
  auto it = tree.find(8);
  assert(it != tree.end);
  assert(it.val == 8);
  
  it = tree.find(7);
  assert(it == tree.end);
}


struct Pair(K, V)
{
    K key;
    V value;
}

int mapCmp(K, V, alias cmp = defaultCmp!(K))(ref Pair!(K, V) lhs, ref Pair!(K, V) rhs)
{
    return cmp(lhs.key, rhs.key);
}

class OrderedMap(K, V, alias cmp = defaultCmp!(K), bool includeSize = true) : RedBlackTree!(Pair!(K, V), mapCmp!(K, V, cmp), includeSize)
{
public:
    void opIndexAssign(V v, K k)
    {
        insert(Pair!(K, V)(k, v));
    }
    
    Iterator find(K k)
    {
        Node* node = root;
        int result;
        while (node != leaf) {
            result = cmp(k, node.val.key);
            if (result == 0) {
                return Iterator(node);
            } else if (result < 0) {
                node = node.left;
            } else {
                node = node.right;
            }
        }
        return end;
    }
    
    V* opIn_r(K k)
    {
        Node* node = root;
        int result;
        while (node != leaf) {
            result = cmp(k, node.val.key);
            if (result == 0) {
                return &node.val.value;
            } else if (result < 0) {
                node = node.left;
            } else {
                node = node.right;
            }
        }
        return null;
    }
}

private void isEqualMap(K, V)(OrderedMap!(K, V) actual, V[K] expected)
{
    if (expected.length == 0) {
        assert(actual.empty);
        assert(actual.begin == actual.end);
        return;
    }
    
    auto count = 0;
    auto it = actual.begin;
    while (it != actual.end) {
        ++count;
        assert(it.val.key in expected);
        assert(it.val.value == expected[it.val.key]);
        ++it;
    }
    assert(count == expected.length);
}


unittest
{
    OrderedMap!(int, int) map = new OrderedMap!(int, int)();
    //isEqualMap(map, cast(int[int])[]);

    map[13] = 1;
    isEqualMap(map, [13:1]);
    
    map[1] = 2;
    isEqualMap(map, [1:2, 13:1]);
    
    map[8] = 3;
    isEqualMap(map, [1:2, 8:3, 13:1]);
    
    map[11] = 4;
    isEqualMap(map, [1:2, 8:3, 11:4, 13:1]);
    
    auto it = map.find(13);
    assert(it != map.end);
    assert(it.val.key == 13);
    
    it = map.find(14);
    assert(it == map.end);
    
    auto v = 13 in map;
    assert(v !is null);
    assert(*v == 1);
    
    v = 14 in map;
    assert(v is null);
}
