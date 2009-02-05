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
    struct Iterator
    {
    public:
        T val() { return _node._val; }
        T val(T v) { return _node._val = v; }
        T* ptr() { return &_node._val; }
        
        Iterator opPostInc()
        { return Iterator((_node = _node._next)._prev); }
        Iterator opPostDec()
        { return Iterator((_node = _node._prev)._next); }
        
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
            while(delta-- > 0) {
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

    public:/*
        invariant() {
            assert(_node !is null);
        }*/
    }

public:
    this()
    {
        clear();
    }

    Iterator begin() { return Iterator(head._next); }
    Iterator end() { return Iterator(head); }
    
    void prepend(T v) {
        insert(begin, v);
    }
    
    void append(T v) {
        insert(end, v);
    }
    
    void insert(Iterator it, T v)
    {
        Node* node = new Node;
        node._val = v;
        node._prev = it._node._prev;
        it._node._prev._next = node;
        node._next = it._node;
        it._node._prev = node;
        static if(includeSize) ++_size;
    }
    
    void erase(Iterator it)
    /*in
    {
        assert(it._node != head);
    }
    body*/
    {
        it._node._prev._next = it._node._next;
        it._node._next._prev = it._node._prev;
        static if(includeSize) --_size;
    }
    
    void clear()
    {
        head._next = head;
        head._prev = head;
        static if(includeSize) _size = 0;
    }
    
    LinkedList split(Iterator it)
    {
        LinkedList copy;
        if (empty) {
            return copy;
        }
        copy.head._next = it._node;
        copy.head._prev = head._prev;
        head._prev._next = copy.head;
        head._prev = it._node._prev;
        it._node._prev._next = head;
        it._node._prev = copy.head;
        
        static if(includeSize) {
            size_t newSize;
            Node* node = head;
            while ( (node = node._next) != head) ++newSize;
            copy._size = newSize;
            _size -= newSize;
        }
        return copy;
    }
    
    void appendAndClear(LinkedList list)
    {
        head._prev._next = list.head._next;
        list.head._next._prev = head._prev;
        head._prev = list.head._prev;
        head._prev._next = head;
        
        static if(includeSize) _size += list._size;
        list.clear();
    }
    
    bool empty() { return head._next == head; }
    
    size_t size()
    {
        static if(includeSize) {
            return _size;
        } else {
            size_t size;
            Node* node = head;
            while ( (node = node._next) != head) ++size;
            return size;
        }
    }
    
    int opApply(int delegate(ref T) dg)
    {
        int result;
        for (Iterator it = begin; it != end && result == 0; ++it)
            result = dg(*it.ptr);
        return result;
    }
    
    int opApply(int delegate(ref size_t, ref T) dg)
    {
        int result;
        size_t i;
        for (Iterator it = begin; it != end && result == 0; ++it) {
            result = dg(i, *it.ptr);
            ++i;
        }
        return result;
    }


private:
    Node* head() { return cast(Node*)&_head; }

    Head _head;
    static if(includeSize) size_t _size;

public:/*
    invariant() {
        static if(includeSize) size_t size;
        Node* node = head;
        if (node._next == node) assert(node._prev == node);
        do {
            assert(node._prev._next == node);
            assert(node._next._prev == node);
            static if(includeSize) ++size;
        } while (node != head)
        static if(includeSize) assert(size == _size);
    }*/
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
}

debug (Test) {
    void main()
    {
    }
}
