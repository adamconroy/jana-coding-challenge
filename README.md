# jana-coding-challenge
Java Interview Coding Challenge

##Setup before running on default OS X installation:
- Install Firefox

- Install bundler

```
[sudo] gem install bundler
```

- Install gems

```
bundle install
```

##To run:

```
ruby find_email_addresses.rb jana.com
```

Note: I've only run this on a default OS X 10.11.2 installation driving Firefox (Watir's default). Let me know if you run into any technical issues with this setup.

## Design/Thoughts

Why Ruby/Watir? I decided to replicate most closely what I would advocate doing for a tool like this in a real scenario with a two hour time limit. I initially wanted to do something in Python to more closely fit what would be used at Jana. After some reseach it really looks like Python doesn't have as robust of a Selenium wrapper as Watir and I'm currently much more comfortable with Ruby so I went this direction to save time.

## Future ideas:
- multithreading (parent script that launches multiple browsers)
- better email validation
- written in node.js with a headless web driver, easily could be run as a distributed cluster on AWS or similar (if you REALLY want those emails)
- lots more error checking as well as registration spoofing and cookie management

^^^
