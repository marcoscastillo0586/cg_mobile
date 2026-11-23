/// Elemento del gráfico que queda resaltado tras un toque: el tocado mientras el dedo sigue apoyado; -1 al
/// soltar o tocar fuera de una barra/porción.
int resaltadoTrasToque({required bool interesado, int? tocado}) => interesado && tocado != null ? tocado : -1;
