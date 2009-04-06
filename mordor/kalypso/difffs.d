module mordor.kalypso.difffs;

import mordor.common.applyiterator;
import mordor.common.containers.linkedlist;
import mordor.common.containers.redblacktree;
import mordor.common.stringutils;
import mordor.kalypso.vfs.model;

void diffFS(IObject lhs, IObject rhs,
            void delegate(IObject lhs, IObject rhs) bothExist,
            IObject delegate(IObject lhs, IObject rhsParent) lhsExists,
            IObject delegate(IObject rhs, IObject lhsParent) rhsExists)
{
    struct LhsAndRhs 
    {
        IObject lhs;
        IObject rhs;
    }
    LinkedList!(LhsAndRhs) toDiff = new LinkedList!(LhsAndRhs);

    void diffChildren(IObject lhs, IObject rhs)
    {
        auto orderedSrc = cast(IOrderedEnumerateObject)lhs;
        auto orderedDst = cast(IOrderedEnumerateObject)rhs;
        if (orderedSrc !is null && orderedDst !is null) {
            scope lhsIt = new ApplyIterator!(IObject)(&lhs.children);
            scope rhsIt = new ApplyIterator!(IObject)(&rhs.children);
            while (!lhsIt.done || !rhsIt.done) {
                if (lhsIt.done) {
                    IObject lhsChild = rhsExists(rhsIt.val, lhs);
                    if (lhsChild !is null)
                        toDiff.append(LhsAndRhs(lhsChild, rhsIt.val));
                    ++rhsIt;
                    continue;                    
                }
                if (rhsIt.done) {
                    IObject rhsChild = lhsExists(lhsIt.val, rhs);
                    if (rhsChild !is null)
                        toDiff.append(LhsAndRhs(lhsIt.val, rhsChild));
                    ++lhsIt;
                    continue;
                }
                string lhsName = lhsIt.val["name"].get!(string);
                string rhsName = rhsIt.val["name"].get!(string);
                if (lhsName < rhsName) {
                    IObject rhsChild = lhsExists(lhsIt.val, rhs);
                    if (rhsChild !is null)
                        toDiff.append(LhsAndRhs(lhsIt.val, rhsChild));
                    ++lhsIt;
                    continue;
                } else if (lhsName == rhsName) {
                    bothExist(lhsIt.val, rhsIt.val);
                    toDiff.append(LhsAndRhs(lhsIt.val, rhsIt.val));
                    ++lhsIt; ++rhsIt;
                    continue;
                } else /* if (rhsName < lhsName) */ {
                    IObject lhsChild = rhsExists(rhsIt.val, lhs);
                    if (lhsChild !is null)
                        toDiff.append(LhsAndRhs(lhsChild, rhsIt.val));
                    ++rhsIt;
                    continue;
                }
            }
        } else if (orderedSrc !is null) {
            scope rhsChildren = new OrderedMap!(string, IObject)();
            foreach(child; &rhs.children) {
                rhsChildren[child["name"].get!(string)] = child;
            }
            scope lhsIt = new ApplyIterator!(IObject)(&lhs.children);
            auto rhsIt = rhsChildren.begin;
            while (!lhsIt.done || rhsIt != rhsChildren.end) {
                if (lhsIt.done) {
                    IObject lhsChild = rhsExists(rhsIt.val.value, lhs);
                    if (lhsChild !is null)
                        toDiff.append(LhsAndRhs(lhsChild, rhsIt.val.value));
                    ++rhsIt;
                    continue;
                }
                if (rhsIt == rhsChildren.end) {
                    IObject rhsChild = lhsExists(lhsIt.val, rhs);
                    if (rhsChild !is null)
                        toDiff.append(LhsAndRhs(lhsIt.val, rhsChild));
                    ++lhsIt;
                    continue;
                }
                
                string lhsName = lhsIt.val["name"].get!(string);
                string rhsName = rhsIt.val.key;
                if (lhsName < rhsName) {
                    IObject rhsChild = lhsExists(lhsIt.val, rhs);
                    if (rhsChild !is null)
                        toDiff.append(LhsAndRhs(lhsIt.val, rhsChild));
                    ++lhsIt;
                    continue;
                } else if (lhsName == rhsName) {
                    bothExist(lhsIt.val, rhsIt.val.value);
                    toDiff.append(LhsAndRhs(lhsIt.val, rhsIt.val.value));
                    ++lhsIt; ++rhsIt;
                    continue;
                } else /* if (rhsName < lhsName) */ {
                    IObject lhsChild = rhsExists(rhsIt.val.value, lhs);
                    if (lhsChild !is null)
                        toDiff.append(LhsAndRhs(lhsChild, rhsIt.val.value));
                    ++rhsIt;
                    continue;
                }
            }
        } else if (orderedDst !is null) {
            scope lhsChildren = new OrderedMap!(string, IObject)();
            foreach(child; &lhs.children) {
                lhsChildren[child["name"].get!(string)] = child;
            }
            auto lhsIt = lhsChildren.begin;
            scope rhsIt = new ApplyIterator!(IObject)(&rhs.children);
            while (lhsIt != lhsChildren.end || !rhsIt.done) {
                if (lhsIt == lhsChildren.end) {
                    IObject lhsChild = rhsExists(rhsIt.val, lhs);
                    if (lhsChild !is null)
                        toDiff.append(LhsAndRhs(lhsChild, rhsIt.val));
                    ++rhsIt;
                    continue;
                }
                if (rhsIt.done) {
                    IObject rhsChild = lhsExists(lhsIt.val.value, rhs);
                    if (rhsChild !is null)
                        toDiff.append(LhsAndRhs(lhsIt.val.value, rhsChild));
                    ++lhsIt;
                    continue;
                }
                
                string lhsName = lhsIt.val.key;
                string rhsName = rhsIt.val["name"].get!(string);
                if (lhsName < rhsName) {
                    IObject rhsChild = lhsExists(lhsIt.val.value, rhs);
                    if (rhsChild !is null)
                        toDiff.append(LhsAndRhs(lhsIt.val.value, rhsChild));
                    ++lhsIt;
                    continue;
                } else if (lhsName == rhsName) {
                    bothExist(lhsIt.val.value, rhsIt.val);
                    toDiff.append(LhsAndRhs(lhsIt.val.value, rhsIt.val));
                    ++lhsIt; ++rhsIt;
                    continue;
                } else /* if (rhsName < lhsName) */ {
                    IObject lhsChild = rhsExists(rhsIt.val, lhs);
                    if (lhsChild !is null)
                        toDiff.append(LhsAndRhs(lhsChild, rhsIt.val));
                    ++rhsIt;
                    continue;
                }
            }
        } else {
            IObject[string] lhsChildren;
            foreach(lhsChild; &lhs.children) {
                lhsChildren[lhsChild["name"].get!(string)] = lhsChild;
            }
            
            foreach(rhsChild; &rhs.children) {
                string rhsName = rhsChild["name"].get!(string);
                IObject* lhsVal = rhsName in lhsChildren;
                if (lhsVal) {
                    bothExist(*lhsVal, rhsChild);
                    toDiff.append(LhsAndRhs(*lhsVal, rhsChild));
                    lhsChildren.remove(rhsName);
                    continue;
                }
                IObject lhsChild = rhsExists(rhsChild, lhs);
                if (lhsChild !is null)
                    toDiff.append(LhsAndRhs(lhsChild, rhsChild));
            }
            
            foreach(name, lhsChild; lhsChildren) {
                IObject rhsChild = lhsExists(lhsChild, rhs);
                if (rhsChild !is null)
                    toDiff.append(LhsAndRhs(lhsChild, rhsChild));
            }
        }
    }
    
    bothExist(lhs, rhs);
    diffChildren(lhs, rhs);
    while (!toDiff.empty()) {
        auto next = toDiff.begin.val;
        toDiff.erase(toDiff.begin);
        diffChildren(next.lhs, next.rhs);
    }
}
