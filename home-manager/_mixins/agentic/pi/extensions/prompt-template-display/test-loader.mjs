const tuiStub = `
export class Box {
  constructor() { this.children = []; }
  addChild(child) { this.children.push(child); }
  render(width) { return this.children.flatMap((child) => child.render(width)); }
}
export class Text {
  constructor(text) { this.text = text; }
  render() { return this.text.split("\\n"); }
}
`;

export async function resolve(specifier, context, nextResolve) {
	if (specifier === "@earendil-works/pi-tui") {
		return {
			shortCircuit: true,
			url: `data:text/javascript,${encodeURIComponent(tuiStub)}`,
		};
	}
	return nextResolve(specifier, context);
}
