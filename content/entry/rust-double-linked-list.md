+++
title = "🔗 Rustでdoubly linked list"
slug = "rust-doubly-linked-list"
date = "2019-08-17"
draft = false
[taxonomies]
tags = ["rust"]
+++

Rustでdoubly linked listを書いてみました。


```rust
use std::cell::RefCell;
use std::fmt;
use std::rc::Rc;

type Link<T> = Rc<RefCell<Node<T>>>;

#[derive(Debug)]
struct Node<T> {
    value: T,
    prev: Option<Link<T>>,
    next: Option<Link<T>>,
}

impl<T> Node<T> {
    fn new(value: T) -> Rc<RefCell<Self>> {
        Rc::new(RefCell::new(Self {
            value,
            prev: None,
            next: None,
        }))
    }
}

#[derive(Default)]
pub struct LinkedList<T> {
    head: Option<Link<T>>,
    tail: Option<Link<T>>,
    length: usize,
}

impl<T> LinkedList<T> {
    pub fn new() -> Self {
        Self {
            head: None,
            tail: None,
            length: 0,
        }
    }

    pub fn len(&self) -> usize {
        self.length
    }

    pub fn append(&mut self, v: T) {
        let node = Node::new(v);
        match self.tail.take() {
            Some(old_tail) => {
                old_tail.borrow_mut().next = Some(Rc::clone(&node));
                node.borrow_mut().prev = Some(old_tail);
            }
            None => {
                // first element
                debug_assert_eq!(self.len(), 0);
                self.head = Some(Rc::clone(&node));
            }
        }

        self.tail = Some(node);
        self.length += 1;
    }

    pub fn pop(&mut self) -> Option<T> {
        match self.tail.take() {
            Some(tail) => {
                if let Some(prev) = tail.borrow_mut().prev.take() {
                    prev.borrow_mut().next = None;
                    self.tail = Some(prev);
                } else {
                    // we take last element
                    debug_assert_eq!(self.len(), 1);
                    self.head = None;
                }
                self.length -= 1;
                let v = Rc::try_unwrap(tail) // Rc<RefCell<Node<T>> -> RefCell<Node<T>>
                    .ok() // Result<RefCell<Node<T>>, Rc<RefCell<Node<T>>>> -> Option<RefCell<Node<T>>>
                    .expect("Failed to Rc::try_unwrap tail node") // RefCell<Node<T>>
                    .into_inner() // RefCell<Node<T>> -> Node<T>
                    .value;
                Some(v)
            }
            None => None,
        }
    }

    pub fn iter(&self) -> Iter<T> {
        Iter {
            current: if self.len() == 0 {
                None
            } else {
                Some(Rc::clone(&self.head.as_ref().unwrap()))
            },
        }
    }
}

```

参照を相互に保持したい場合、`Rc<RefCell<T>>`でWrapしてやる必要があります。
Goならpointerを相互のfieldに代入すればよいだけなのですが、Rustの場合、`Rc`で参照の所有者が複数いることを、`RefCell`で、参照先からでも値が変更
できることを表現する必要があります。
型をみるだけで、この値は複数箇所で保持されていて、さらに変更されるうることまでわかりますね。
また、`Rc::clone()`は`node.clone()`のようにmethod呼び出しではなく、`Rc::clone(&node)`のように明示的に、reference countedのcloneであることがわかるように呼ぶのが慣習だそうです。(`node.clone()`とあると、重たい処理かもしれないと思ってしまうからでしょうか。)

`Rc<RefCell<T>>`の`T`のfieldの所有権を奪おうとすると大変で、`Rc::try_unwrap()`して、`RefCell<T>`に変換してさらに`RefCell::into_inner()` で、T型にもどしてやる必要があります。

続いて、`fmt::Debug`を実装します。

```rust
impl<T: fmt::Display + Clone> fmt::Debug for LinkedList<T> {
    fn fmt(&self, f: &mut fmt::Formatter) -> Result<(), fmt::Error> {
        let iter = self.iter();
        write!(f, "{{ head")?;
        for v in iter {
            write!(f, " -> {}", v)?;
        }
        write!(f, " }}")
    }
}
```
この実装がないと、`println!("{:?}", list);` としたときに、`Node`同士が相互参照しているので、循環参照してしまい、stackoverflowしてしまいます。
これを回避するには、どちからの参照を`rc::Weak`にしてもよいと思ったのですが、prev側を無視することにしました。

最後にiteratorを実装します。

```rust
impl<T: Clone> IntoIterator for LinkedList<T> {
    type Item = T;
    type IntoIter = Iter<T>;

    fn into_iter(self) -> Self::IntoIter {
        self.iter()
    }
}

pub struct Iter<T> {
    current: Option<Link<T>>,
}

impl<T: Clone> Iterator for Iter<T> {
    type Item = T;
    fn next(&mut self) -> Option<Self::Item> {
        match self.current.take() {
            None => None,
            Some(curr) => {
                let curr = curr.borrow();
                let v = curr.value.clone();
                match curr.next {
                    None => {
                        self.current = None;
                    }
                    Some(ref next) => {
                        self.current = Some(Rc::clone(next));
                    }
                }
                Some(v)
            }
        }
    }
}

impl<T: Clone> DoubleEndedIterator for Iter<T> {
    fn next_back(&mut self) -> Option<T> {
        match self.current.take() {
            None => None,
            Some(curr) => {
                let curr = curr.borrow();
                match curr.prev {
                    None => {
                        self.current = None;
                        None
                    }
                    Some(ref prev) => {
                        self.current = Some(Rc::clone(prev));
                        Some(prev.borrow().value.clone())
                    }
                }
            }
        }
    }
}
```
`T`には`Clone` boundを設けて楽をしました。`DoubleEndedIterator`を実装すると

```rust
    #[test]
    fn reverse() {
        let mut list: LinkedList<i32> = LinkedList::new();
        (0..10).for_each(|n| list.append(n));

        let mut iter = list.iter();
        assert_eq!(iter.next(), Some(0));
        assert_eq!(iter.next(), Some(1));
        assert_eq!(iter.next(), Some(2));
        assert_eq!(iter.next(), Some(3));
        assert_eq!(iter.next_back(), Some(3));
        assert_eq!(iter.next_back(), Some(2));
        assert_eq!(iter.next_back(), Some(1));
        assert_eq!(iter.next_back(), Some(0));
        assert_eq!(iter.next_back(), None);
    }
```

このように、戻れるようになりました。
[sourceはこちら](https://github.com/ymgyt/dsa/blob/master/src/list/linked_list.rs)


## 参考

* [Hands-On Data Structures and Algorithms with Rust](https://www.amazon.co.jp/dp/178899552X)

