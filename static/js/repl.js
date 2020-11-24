const {
	Record,
	StoreOf,
	Component,
	ListOf,
} = window.Torus;

const BLOCK = {
	TEXT: 0,
	CODE: 1,
}

class Para extends Record {
    childIndexes() {
        const childIndex = (this.get('index') + this.get('next')) / 2;
        const childNext = this.get('next');
        this.update({next: childIndex});

        return {
            index: childIndex,
            next: childNext,
        }
    }
}

class Doc extends StoreOf(Para) {
    get comparator() {
        return block => block.get('index');
    }
}

function remoteEval(expr) {
	return fetch('/eval', {
		method: 'POST',
		body: expr,
	}).then(resp => resp.text());
}

class Block extends Component {
	init(para, remover, {addTextBlock, addCodeBlock}) {
		this.editing = false;

		this.evaling = false;
		this.evaled = null;

		this.remover = remover;
		this.addTextBlock = () => addTextBlock(this.record.childIndexes());
		this.addCodeBlock = () => addCodeBlock(this.record.childIndexes());
		this.startEditing = this.startEditing.bind(this);

		this.bind(para, this.render.bind(this));

        // if code block, exec code on first load
        if (this.evaled == null) {
            this.eval();
        }
	}
    async eval(evt) {
        this.evaling = true;
        this.render();
        this.evaled = await remoteEval(evt ? evt.target.value : this.record.get('text'));
        this.evaling = false;
        this.render();
    }
	startEditing(evt) {
		this.editing = true;
		this.render();
	}
	compose() {
		const {type, text} = this.record.summarize();
		const buttons = jdom`<div class="block-buttons"
            onclick=${evt => evt.stopPropagation()}>
			<button onclick=${this.remover}>del</button>
			<button onclick=${this.addTextBlock}>+ text</button>
			<button onclick=${this.addCodeBlock}>+ code</button>
		</div>`;

		if (type == BLOCK.CODE) {
			return jdom`<div class="block block-code wrap paper ${this.evaling ? 'evaling' : ''}"
				tabIndex=${this.evaling ? -1 : 0}>
				${buttons}
				<div class="block-code-editor">
					<textarea
						class="textarea-code"
						value=${text}
						oninput=${evt => this.record.update({
							text: evt.target.value,
						})}
						onkeydown=${evt => {
							if (evt.key == 'Enter' && (evt.ctrlKey || evt.metaKey)) {
                                this.eval(evt);
							}
						}} />
				</div>
				<div class="block-code-result">
                    ${this.evaled || '(none)'}
				</div>
			</div>`
		}

		if (this.editing) {
			return jdom`<textarea
				class="textarea-text"
				value=${text}
				onkeydown=${evt => {
					if (evt.key == 'Enter' && (evt.ctrlKey || evt.metaKey)) {
						this.editing = false;
						this.record.update({
							text: evt.target.value.trim(),
						});
					} else if (evt.key == 'Escape') {
						this.editing = false;
						this.render();
					}
				}} />`;
		}

		return jdom`<div class="block block-text" onclick=${this.startEditing}>
			${buttons}
			${Markus(text)}
		</div>`
	}
}

class Editor extends ListOf(Block) {
	compose() {
		return jdom`<main class="editor">
			${this.nodes}
		</main>`;
	}
}

// Helper fn for a default (test) doc
let index = 0;
function para(text) {
	return new Para({
		type: BLOCK.TEXT,
		text,
        index: index++,
        next: index,
	});
}
function code(text) {
	return new Para({
		type: BLOCK.CODE,
		text,
        index: index++,
        next: index,
	});
}

class App extends Component {
	init() {
		this.doc = new Doc([
			para('# A tour of Nightvale'),
			para(`*Nightvale* is a rich interactive notebook that runs Klisp. You can click on any block of text to edit it as Markdown or modify a program.`),
			code('(+ 1 2 3 4)'),
		]);
		this.editor = new Editor(this.doc, {
			addTextBlock: childIndexes => this.doc.create(null, {
                type: BLOCK.TEXT,
                text: 'Say something...',
                ...childIndexes,
            }),
			addCodeBlock: childIndexes => this.doc.create(null, {
                type: BLOCK.CODE,
                text: '(+ 1 1)',
                ...childIndexes,
            }),
		});
	}
	compose() {
		return jdom`<div class="app">
			<header>
				<div class="left">
					<a href="/">Nightvale</a>
				</div>
				<div class="center">
				</div>
				<div class="right">
					<a href="/about">about</a>
				</div>
			</header>
			${this.editor.node}
			<footer>
				<div class="left">
					Made by
					<a href="https://thesephist.com/">Linus</a>
				</div>
				<div class="center">
				</div>
				<div class="right">
					Built with 
					<a href="https://github.com/thesephist/klisp">Klisp</a>,
					<a href="https://dotink.co/">Ink</a>,
					and
					<a href="https://github.com/thesephist/torus">Torus</a>
				</div>
			</footer>
		</div>`;
	}
}

const app = new App();
document.body.appendChild(app.node);

