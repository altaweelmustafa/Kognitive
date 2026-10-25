import 'lines_category.dart';
import 'lines_logic.dart';

/// Passages bundled with the app, for when the internet can't be reached.
/// The technical ones are written for Kognitiv; the novels are public-domain
/// openings.
List<Passage> fallbackPassages(LinesCategory category) => switch (category) {
  LinesCategory.cybersecurity => const [
    Passage(
      title: 'Phishing',
      source: 'Kognitiv',
      text:
          'Phishing is an attack in which a message pretends to come from a '
          'trusted sender. The attacker hopes the reader will click a link or '
          'open an attachment without thinking. Many phishing emails create a '
          'false sense of urgency, warning that an account will be locked '
          'unless the reader acts at once.',
    ),
    Passage(
      title: 'Password hashing',
      source: 'Kognitiv',
      text:
          'A well-built system never stores passwords as plain text. Instead '
          'it stores a hash, a fixed-length value computed from the password '
          'by a one-way function. When a user signs in, the system hashes the '
          'typed password again and compares the two values. A random salt is '
          'added first, so identical passwords produce different hashes.',
    ),
    Passage(
      title: 'Ransomware',
      source: 'Kognitiv',
      text:
          'Ransomware is malicious software that encrypts the files on a '
          'computer and demands payment for the key. It often spreads through '
          'infected attachments or unpatched servers. Regular offline backups '
          'are the most reliable defence, because they let an organisation '
          'restore its data without paying the criminals.',
    ),
  ],
  LinesCategory.networking => const [
    Passage(
      title: 'Domain Name System',
      source: 'Kognitiv',
      text:
          'The Domain Name System translates names that people remember into '
          'the numeric addresses that computers use. When you type a web '
          'address, your device asks a resolver, which may query several '
          'servers before it finds the answer. Results are cached for a while, '
          'so repeated lookups are much faster.',
    ),
    Passage(
      title: 'Routers',
      source: 'Kognitiv',
      text:
          'A router connects separate networks and forwards packets between '
          'them. For each packet it reads the destination address and consults '
          'a routing table to choose the next hop. Routers exchange information '
          'with their neighbours, so the tables adjust when a link fails or '
          'becomes congested.',
    ),
    Passage(
      title: 'TCP',
      source: 'Kognitiv',
      text:
          'The Transmission Control Protocol provides reliable delivery on top '
          'of an unreliable network. Every segment is numbered, and the '
          'receiver sends acknowledgements for the data it has received. '
          'Anything that is not acknowledged in time is transmitted again, and '
          'the sender slows down when the network shows signs of congestion.',
    ),
  ],
  LinesCategory.programming => const [
    Passage(
      title: 'Recursion',
      source: 'Kognitiv',
      text:
          'A recursive function solves a problem by calling itself on a '
          'smaller version of the same problem. Every recursive function needs '
          'a base case that can be answered directly; without one, the calls '
          'would continue until the program ran out of memory. Many tree and '
          'graph algorithms are naturally expressed this way.',
    ),
    Passage(
      title: 'Version control',
      source: 'Kognitiv',
      text:
          'A version control system records every change made to a set of '
          'files. Developers can compare old and new versions, find out who '
          'introduced a bug, and restore earlier work. Branches let several '
          'people develop features in parallel and merge them back together '
          'when they are finished.',
    ),
    Passage(
      title: 'Compilers',
      source: 'Kognitiv',
      text:
          'A compiler translates source code written by people into '
          'instructions a machine can execute. It first checks that the '
          'program follows the rules of the language and reports errors it '
          'finds. It then optimises the code, removing needless work so that '
          'the finished program runs faster.',
    ),
  ],
  LinesCategory.medicine => const [
    Passage(
      title: 'Vaccines',
      source: 'Kognitiv',
      text:
          'A vaccine trains the immune system to recognise a pathogen before '
          'a real infection occurs. It contains a harmless piece or weakened '
          'form of the germ. The body responds by producing antibodies and '
          'memory cells, which can react quickly if the genuine pathogen ever '
          'appears.',
    ),
    Passage(
      title: 'Blood pressure',
      source: 'Kognitiv',
      text:
          'Blood pressure is the force that circulating blood exerts on the '
          'walls of the arteries. It is recorded as two numbers: the pressure '
          'while the heart contracts and the pressure while it relaxes. '
          'Persistently high readings strain the heart and damage blood '
          'vessels over many years.',
    ),
    Passage(
      title: 'Antibiotics',
      source: 'Kognitiv',
      text:
          'Antibiotics are medicines that kill bacteria or stop them from '
          'multiplying. They have no effect on viruses, so they cannot cure a '
          'cold. When antibiotics are used carelessly, the surviving bacteria '
          'can evolve resistance, and infections become much harder to treat.',
    ),
  ],
  LinesCategory.novels => const [
    Passage(
      title: 'Pride and Prejudice',
      author: 'Jane Austen',
      source: 'Project Gutenberg',
      text:
          'It is a truth universally acknowledged, that a single man in '
          'possession of a good fortune, must be in want of a wife. However '
          'little known the feelings or views of such a man may be on his first '
          'entering a neighbourhood, this truth is so well fixed in the minds '
          'of the surrounding families, that he is considered the rightful '
          'property of some one or other of their daughters.',
    ),
    Passage(
      title: 'Moby-Dick',
      author: 'Herman Melville',
      source: 'Project Gutenberg',
      text:
          'Call me Ishmael. Some years ago, never mind how long precisely, '
          'having little or no money in my purse, and nothing particular to '
          'interest me on shore, I thought I would sail about a little and see '
          'the watery part of the world. It is a way I have of driving off the '
          'spleen and regulating the circulation.',
    ),
    Passage(
      title: "Alice's Adventures in Wonderland",
      author: 'Lewis Carroll',
      source: 'Project Gutenberg',
      text:
          'Alice was beginning to get very tired of sitting by her sister on '
          'the bank, and of having nothing to do. Once or twice she had peeped '
          'into the book her sister was reading, but it had no pictures or '
          'conversations in it, and what is the use of a book, thought Alice, '
          'without pictures or conversations?',
    ),
  ],
};
