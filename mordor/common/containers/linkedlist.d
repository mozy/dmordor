module mordor.common.containers.linkedlist;

class LinkedList(T, bool includeSize = true)
{
private:
    struct Node
    {
        Node* _next;
        Node* _prev;
        T _val;
    }

    struct Head
    {
        Node* _next;
        Node* _prev;
    }

public:
    static struct Iterator
    {
    public:
        T val() { return _node._val; }
        T val(T v) { return _node._val = v; }
        T* ptr() { return &_node._val; }

        Iterator opPostInc()
        {
            Node* node = _node;
            _node = _node._next;
            return Iterator(node);
        }

        Iterator opPostDec()
        {
            Node* node = _node;
            _node = _node._prev;
            return Iterator(node);
        }

        Iterator opAdd(ptrdiff_t delta)
        {
            Node* node = _node;
            while(delta > 0) {
                node = node._next;
                --delta;
            }
            while(delta < 0) {
                node = node._prev;
                ++delta;
            }
            return Iterator(node);
        }

        Iterator opSub(ptrdiff_t delta)
        {
            Node* node = _node;
            while(delta > 0) {
                node = node._prev;
                --delta;
            }
            while(delta < 0) {
                node = node._next;
                ++delta;
            }
            return Iterator(node);
        }

        Iterator opAddAssign(ptrdiff_t delta)
        {
            while(delta > 0) {
                _node = _node._next;
                --delta;
            }
            while(delta < 0) {
                _node = _node._prev;
                ++delta;
            }
            return *this;
        }

        Iterator opSubAssign(ptrdiff_t delta)
        {
            while(delta > 0) {
                _node = _node._prev;
                --delta;
            }
            while(delta < 0) {
                _node = _node._next;
                ++delta;
            }
            return *this;
        }

    private:
        Node* _node;

    public:
        invariant() {
            assert(_node !is null);
        }
    }

public:
    this()
    {
        head._next = head;
        head._prev = head;
        static if(includeSize) _size = 0;
    }

    Iterator begin() { return Iterator(head._next); }
    Iterator end() { return Iterator(head); }

    void prepend(T v)
    {
        insert(begin, v);
    }

    void append(T v)
    {
        insert(end, v);
    }

    void insert(Iterator it, T v)
    {
        Node* node = new Node;
        node._val = v;
        node._next = it._node;
        node._prev = it._node._prev;
        it._node._prev._next = node;
        it._node._prev = node;
        static if(includeSize) ++_size;
    }

    void erase(Iterator it) 
    in
    {
        assert(it != end);
    }
    body
    {
        it._node._prev._next = it._node._next;
        it._node._next._prev = it._node._prev;
        static if(includeSize) --_size;
    }
    
    void erase(Iterator start, Iterator stop)
    in
    {
        assert(start != end);
    }
    body
    {
        start._node._prev._next = stop._node;
        stop._node._prev = start._node._prev;
        static if(includeSize) {
            Node* node = start._node;
            while (node != stop._node) {
                --_size;
                node = node._next;
            }
        }
    }

    void clear()
    {
        head._next = head;
        head._prev = head;
        static if(includeSize) _size = 0;
    }

    bool empty() { return head._next == head; }

    size_t size()
    {
        static if(includeSize) {
            return _size;
        } else {
            size_t size;
            Node* node = head;
            while( (node = node._next) != head) ++size;
            return size;
        }
    }

    int opApply(int delegate(ref T) dg) {
        int result;
        for(auto it = begin; it != end; ++it)
        {
            if ((result = dg(*it.ptr)) != 0) return result;
        }
        return 0;
    }
    
    int opApply(int delegate(ref size_t, ref T) dg) {
        int result;
        size_t i;
        for(auto it = begin; it != end; ++it)
        {
            if ((result = dg(i, *it.ptr)) != 0) return result;
            ++i;
        }
        return 0;
    }

private:
    Node* head() { return cast(Node*)&_head; }
    Head _head;
    static if(includeSize) size_t _size;

    invariant() {
        Node* node = head;
        static if(includeSize) size_t s;
        if (node._next == node) assert(node._prev == node);
        do {
            assert(node._prev._next == node);
            assert(node._next._prev == node);
            node = node._next;
            static if(includeSize) ++s;
        } while (node != head)
        --s;
        static if(includeSize) assert(_size == s);
    }
}

unittest {
    LinkedList!(int) list = new LinkedList!(int)();
    assert(list.size == 0);
    assert(list.empty);
    assert(list.begin == list.end);
    list.append(1);
    assert(list.size == 1);
    assert(!list.empty);
    assert(list.begin != list.end);
    list.Iterator it = list.begin;
    assert(it.val == 1);
    ++it;
    assert(it == list.end);
    list.erase(list.begin);
    assert(list.size == 0);
    assert(list.empty);
    assert(list.begin == list.end);
}
