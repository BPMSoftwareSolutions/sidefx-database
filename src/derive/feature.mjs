import { Parser, AstBuilder, GherkinClassicTokenMatcher } from '@cucumber/gherkin';

export function parseFeature(text) {
  let next=0;
  const parser = new Parser(new AstBuilder(() => String(next++)), new GherkinClassicTokenMatcher());
  return parser.parse(text);
}
export function featureScenarios(feature) {
  const result=[];
  function children(items, inherited) {
    for (const child of items ?? []) {
      if (child.scenario) result.push({ scenario:child.scenario, inherited });
      if (child.rule) children(child.rule.children, [...inherited, ...(child.rule.tags ?? [])]);
    }
  }
  children(feature.children, feature.tags ?? []);
  return result;
}
export function tagsToValues(tags) {
  const values={};
  for(const {name} of tags) {
    const match=/^@([^:]+)(?::(.*))?$/.exec(name);
    if(match) (values[match[1]] ??= []).push(match[2] ?? true);
  }
  return values;
}
