//> A renderer for a custom flavor of markdown, that renders
//  live, with every keystroke. I wrote the `Marked` component
//  to be integrated into my productivity apps (I'm rewriting my
//  notes and todo apps soon), but it also works well as a live
//  editor by itself.

//> Like `jdom.js`, this is a unique object that identifies
//  that a reader has reached the last character/line to read. Used
//  for parsing strings.
const READER_END = [];
//> These are the regular expressions (`RE`) that match things
//  like headers, images, and quotes.
const RE_HEADER = /^(#{1,6})\s*(.*)/;
const RE_IMAGE = /^%\s+(\S*)/;
const RE_QUOTE = /^(>+)\s*(.*)/;
const RE_LIST_ITEM = /^(\s*)(-|\d+\.)\s+(.*)/;

//> Delimiters for text styles. If you want the more
//  standard flavor of markdown, you can change these
//  these delimiters to get 90% of the way there (minus
//  the links).
const ITALIC_DELIMITER = '_';
const BOLD_DELIMITER = '*';
const STRIKE_DELIMITER = '~';
const CODE_DELIMITER = '`';
const LINK_DELIMITER_LEFT = '<';
const LINK_DELIMITER_RIGHT = '>';
const PRE_DELIMITER = '```';
const LITERAL_DELIMITER = '%%';

//> Some text expansions / replacements I find convenient.
const BODY_TEXT_TRANSFORMS = new Map([
    // RegExp: replacement
    [/--/g, '—'], // em-dash from two dashes
    [/(\?!|!\?)/g, '‽'], // interrobang!
    [/\$\$/g, '💵'],
    [/:\)/g, '🙂'],
    [/<3/g, '❤️'],
    [/:wave:/g, '👋'],
    [/->/g, '→'],
    [/<-/g, '→'],
]);

//> A generator that yields characters from a string, used for parsing text.
class Reader {

    constructor(str) {
        this.str = str;
        this.idx = 0;
    }

    next() {
        return this.str[this.idx ++] || READER_END;
    }

    //> Look ahead a character, but don't increment the position.
    ahead() {
        return this.str[this.idx] || READER_END;
    }

    //> Reads the string until the first occurrence of a given character.
    until(char) {
        const sub = this.str.substr(this.idx);
        const nextIdx = sub.indexOf(char);
        const part = sub.substr(char, nextIdx);
        this.idx += nextIdx + 1;
        return part;
    }

}

//> Like `Reader`, but for lines. It's used for things like parsing nested lists
//  and block quotes.
class LineReader {

    constructor(lines) {
        this.lines = lines;
        this.idx = 0;
    }

    next() {
        if (this.idx < this.lines.length) {
            return this.lines[this.idx ++];
        } else {
            this.idx = this.lines.length;
            return READER_END;
        }
    }

    //> Decrement the counter, so `next()` will return the same line once again.
    backtrack() {
        this.idx = this.idx - 1 < 0 ? 0 : this.idx - 1;
    }

}

//> Parse "body text", which may include italics, bold text, strikethroughs,
//  and inline code blocks. This also takes care of text expansions defined above.
const parseBody = (reader, tag, delimiter = '') => {
    const children = [];
    let buf = '';
    //> Function to "commit" the text read into the buffer as a child
    //  of body text, so we can add other elements after it.
    const commitBuf = () => {
        for (const re of BODY_TEXT_TRANSFORMS.keys()) {
            buf = buf.replace(re, BODY_TEXT_TRANSFORMS.get(re));
        }
        children.push(buf);
        buf = '';
    }
    let char;
    let last = '';
    //> Loop through each character. If there are delimiters, read until
    //  the end of the delimited chunk of text and parse the contents inside
    //  as the right tag.
    while (last = char, char = reader.next()) {
        switch (char) {
            //> Backslash is an escape character, so anything that comes
            //  right after it is just read into the buffer.
            case '\\':
                buf += reader.next();
                break;
            //> If we find the delimiter `parseBody` was called with, that means
            //  we've reached the end of the delimited sequence of text we were
            //  reading from `reader` and must return control flow to the calling function.
            case delimiter:
                if (last === ' ') {
                    buf += char;
                } else {
                    commitBuf();
                    return {
                        tag: tag,
                        children: children,
                    }
                }
                break;
            //> If we reach the end of the body text, commit everything we've got
            //  so far and return the whole thing.
            case READER_END:
                commitBuf();
                return {
                    tag: tag,
                    children: children,
                }
            //> Each of these delimiter cases check if the next character
            //  is a space. If it is, it may just be that the user is trying to type, e.g.
            //  3 < 10 or async / await. We don't count those characters as styling delimiters.
            //  That would be annoying for the user.
            case ITALIC_DELIMITER:
                if (reader.ahead() === ' ') {
                    buf += char;
                } else {
                    commitBuf();
                    children.push(parseBody(reader, 'em', ITALIC_DELIMITER));
                }
                break;
            case BOLD_DELIMITER:
                if (reader.ahead() === ' ') {
                    buf += char;
                } else {
                    commitBuf();
                    children.push(parseBody(reader, 'strong', BOLD_DELIMITER));
                }
                break;
            case STRIKE_DELIMITER:
                if (reader.ahead() === ' ') {
                    buf += char;
                } else {
                    commitBuf();
                    children.push(parseBody(reader, 'strike', STRIKE_DELIMITER));
                }
                break;
            case CODE_DELIMITER:
                if (reader.ahead() === ' ') {
                    buf += char;
                } else {
                    commitBuf();
                    children.push({
                        tag: 'code',
                        //> Rather than recursively parsing the text inside a code
                        //  block, we just take it verbatim. Otherwise symbols like * and /
                        //  in code have to be escaped, which would be really annoying.
                        children: [reader.until(CODE_DELIMITER)],
                    });
                }
                break;
            //> If we find a link, we read until the end of the link and return
            //  a JDOM object that's a clickable link tag that opens in another tab.
            case LINK_DELIMITER_LEFT:
                if (reader.ahead() === ' ') {
                    buf += char;
                } else {
                    commitBuf();
                    const url = reader.until(LINK_DELIMITER_RIGHT);
                    children.push({
                        tag: 'a',
                        attrs: {
                            href: url || '#',
                            rel: 'noopener',
                            target: '_blank',
                        },
                        children: [url],
                    });
                }
                break;
            //> If none of the special cases matched, just add the character
            //  to the buffer we're reading to.
            default:
                buf += char;
                break;
        }
    }

    throw new Error('This should not happen while reading body text!');
}

//> Given a reader of lines, parse (potentially) nested lists recursively.
const parseList = lineReader => {
    const children = [];

    //> We check out the first line in the sequence to determine
    //  how far indented we are, and what kind of list (number, bullet)
    //  it is.
    let line = lineReader.next();
    const [_, indent, prefix] = RE_LIST_ITEM.exec(line);
    const tag = prefix === '-' ? 'ul' : 'ol';
    const indentLevel = indent.length;
    lineReader.backtrack();

    //> Loop through the next few lines from the reader.
    while ((line = lineReader.next()) !== READER_END) {
        const [_, _indent, prefix] = RE_LIST_ITEM.exec(line) || [];
        //> If there's a valid list item prefix, we count it as a list item.
        if (prefix) {
            //> We compare the indentation level of this line, versus the
            //  first line in the list.
            const thisIndentLevel = line.indexOf(prefix);
            //> If it's indented less, we've stumbled upon the end of the
            //  list section. Backtrack and return control to the parent list
            //  or block.
            if (thisIndentLevel < indentLevel) {
                lineReader.backtrack();
                return {
                    tag: tag,
                    children: children,
                }
            //> If it's the same indentation, treat it as the next item in the list.
            //  Parse the list content as body text, and add it to the list of children.
            } else if (thisIndentLevel === indentLevel) {
                const body = line.match(/\s*(?:\d+\.|-)\s*(.*)/)[1];
                children.push(parseBody(new Reader(body), 'li'));
            //> If this line is indented farther than the first line,
            //  that means it's the start of a further-nested list.
            //  Call `parseList` recursively, and add the returned list
            //  as a child.
            } else { // thisIndentLevel > indentLevel
                lineReader.backtrack();
                children.push(parseList(lineReader));
            }
        //> If there's no valid list item prefix, it's the end of the list.
        } else {
            lineReader.backtrack();
            return {
                tag: tag,
                children: children,
            }
        }
    }
    return {
        tag: tag,
        children: children,
    }
}

//> Like `parseList`, but for nested block quotes.
const parseQuote = lineReader => {
    const children = [];

    //> Look ahead at the first line to determine how far nested we are.
    let line = lineReader.next();
    const [_, nestCount] = RE_QUOTE.exec(line);
    const nestLevel = nestCount.length;
    lineReader.backtrack();

    //> Loop through each line in the block quote.
    while ((line = lineReader.next()) !== READER_END) {
        const [_, nestCount, quoteText] = RE_QUOTE.exec(line) || [];
        //> If we're able to find a line matching the block quote regex,
        //  count it as another line in the block.
        if (quoteText !== undefined) {
            const thisNestLevel = nestCount.length;
            //> If this line is nested less than the first line,
            //  it's the end of this block quote. Return control to the
            //  parent block quote.
            if (thisNestLevel < nestLevel) {
                lineReader.backtrack();
                return {
                    tag: 'q',
                    children: children,
                }
            //> If this line is indented same as the first line,
            //  continue reading the quote.
            } else if (thisNestLevel === nestLevel) {
                children.push(parseBody(new Reader(quoteText), 'p'));
            //> If this line is indented further in, it's the start
            //  of another nested quote block. Call itself recursively.
            } else { // thisNestLevel > nestLevel
                lineReader.backtrack();
                children.push(parseQuote(lineReader));
            }
        //> If the line didn't match the block quote regex, it's
        //  the end of the block quote, so return what we have.
        } else {
            lineReader.backtrack();
            return {
                tag: 'q',
                children: children,
            }
        }
    }
    return {
        tag: 'q',
        children: children,
    }
}

//> Main Torus function component for the parser. This component takes
//  a string input, parses it into JDOM (HTML elements), and returns it
//  in a `<div>`.
const Markus = str => {

    //> Make a new line reader that we'll pass to functions to read the input.
    const lineReader = new LineReader(str.split('\n'));

    //> Various parsing state registers.
    let inCodeBlock = false;
    let codeBlockResult = '';
    let inLiteralBlock = false;
    let literalBlockResult = '';
    const result = [];

    let line;
    while ((line = lineReader.next()) !== READER_END) {
        //> If we're in a code block, don't do more parsing
        //  and add the line directly to the code block
        if (inCodeBlock) {
            if (line === PRE_DELIMITER) {
                result.push({
                    tag: 'pre',
                    children: [codeBlockResult],
                });
                inCodeBlock = false;
                codeBlockResult = '';
            } else {
                if (!codeBlockResult) {
                    codeBlockResult = line.trimStart() + '\n';
                } else {
                    codeBlockResult += line + '\n';
                }
            }
        //> ... likewise for literal HTML blocks.
        } else if (inLiteralBlock) {
            if (line === LITERAL_DELIMITER) {
                const wrapper = document.createElement('div');
                wrapper.innerHTML = literalBlockResult;
                result.push(wrapper);
                inLiteralBlock = false;
                literalBlockResult = '';
            } else {
                literalBlockResult += line;
            }
        //> If the line starts with a hash sign, it's a header! Parse it as such.
        } else if (line.startsWith('#')) {
            const [_, hashes, header] = RE_HEADER.exec(line);
            //> The HTML tag is `'h'` followed by the number of `#` signs.
            result.push(parseBody(new Reader(header), 'h' + hashes.length));
        //> If the line matches the image line format, parse the URL
        //  out of the line and add a link that wraps the image, so it's clickable
        //  in the final result HTML.
        } else if (RE_IMAGE.exec(line)) {
            const [_, imageURL] = RE_IMAGE.exec(line);
            result.push({
                tag: 'a',
                attrs: {
                    href: imageURL || '#',
                    rel: 'noopener',
                    target: '_blank',
                    style: {cursor: 'pointer'},
                },
                children: [{
                    tag: 'img',
                    attrs: {
                        src: imageURL,
                        style: {maxWidth: '100%'},
                    },
                }],
            });
        //> If the line matches a block quote format, backtrack
        //  and send the control off to the block quote parser, including the
        //  line we just read.
        } else if (RE_QUOTE.exec(line)) {
            lineReader.backtrack();
            result.push(parseQuote(lineReader));
        //> Detect horizontal dividers and handle it.
        } else if (line === '- -') {
            result.push({tag: 'hr'});
        //> Detect start of a code block
        } else if (line === PRE_DELIMITER) {
            inCodeBlock = true;
        //> Detect start of a literal HTML block
        } else if (line === LITERAL_DELIMITER) {
            inLiteralBlock = true;
        //> Detect list formats (numbered, bullet) and
        //  if they're found, send the control flow off to
        //  the list parsing function.
        } else if (RE_LIST_ITEM.exec(line)) {
            lineReader.backtrack();
            result.push(parseList(lineReader));
        //> If none of the above match, it's a plain old boring
        //  paragraph. Read the line as a paragraph body.
        } else {
            result.push(parseBody(new Reader(line), 'p'));
        }
    }

    //> Return the array of children wrapped in a `<div>`, with some padding
    //  at the bottom so it's freely scrollable during editing.
    return result;
}

