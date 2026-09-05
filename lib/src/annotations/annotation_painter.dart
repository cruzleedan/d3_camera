// AnnotationPainter: the ONE CustomPainter used for both live overlay and
// export rendering. Must never fork into two rendering code paths — see
// design doc §11 for why this is the rule that can't bend.
