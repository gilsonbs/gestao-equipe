import { marked } from 'marked';

marked.setOptions({ breaks: true });

const ALLOWED_TAGS = /^(p|br|strong|em|ul|ol|li|code|pre|h[1-6]|blockquote|hr)$/i;

function sanitize(html: string): string {
  return html.replace(/<\/?([a-z][a-z0-9]*)\b[^>]*>/gi, (tag, name) =>
    ALLOWED_TAGS.test(name) ? tag : ''
  );
}

export function renderMd(text: string): string {
  if (!text) return '';
  return sanitize(marked.parse(text) as string);
}
