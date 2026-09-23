# Fix: navigation after returning

Screens stopped navigating once the reader returned to them: a cancelled effect
consumer permanently finished the model's one effect stream.
