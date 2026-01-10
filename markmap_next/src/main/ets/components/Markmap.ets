import { MarkmapNodeData } from '../utils/MarkdownParse';

@Component
export struct Markmap {
  @Prop markdown: string;
  @State markNodeData: MarkmapNodeData= new MarkmapNodeData;

  build() {
  }
}