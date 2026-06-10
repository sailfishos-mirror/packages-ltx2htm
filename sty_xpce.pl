/*  Part of SWI-Prolog

    Author:        Jan Wielemaker
    E-mail:        J.Wielemaker@vu.nl
    WWW:           http://www.swi-prolog.org
    Copyright (c)  1999-2020, University of Amsterdam
                              VU University Amsterdam
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions
    are met:

    1. Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.

    2. Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in
       the documentation and/or other materials provided with the
       distribution.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
*/

:- module(latex2html4xpce, []).
:- use_module(latex2html,
	      [ latex2html_module/0,
	        tex_load_commands/1,
	        translate/3,
	        add_to_index/1,
	        clean_tt/2,
	        add_to_index/2,
	        translate_table/3
	      ]).
:- use_module(library(apply), [maplist/3]).
:- use_module(library(lists), [append/3, delete/3]).

:- latex2html_module.
:- tex_load_commands(xpce).
:- op(100, fx, #).                          % should be imported

%       XPCE <-> ProWindows switch

:- dynamic
    pwtrue/0.                               % ProWindows 3.1

cmd(makepw, _, []) :-
    assert(pwtrue).
cmd(ifpw({If}, {Else}), Mode, HTML) :-
    (   pwtrue
    ->  translate(If, Mode, HTML)
    ;   translate(Else, Mode, HTML)
    ).

env(pwonly(_, Tokens), HTML) :-
    (   pwtrue
    ->  translate(Tokens, normal, HTML)
    ;   HTML = []
    ).
env(xpceonly(_, Tokens), HTML) :-
    (   pwtrue
    ->  HTML = []
    ;   translate(Tokens, normal, HTML)
    ).

%cmd(product, 'ProWindows') :- pwtrue.
%cmd(product, 'XPCE').
%cmd(productpl, 'ProWindows') :- pwtrue.
%cmd(productpl, 'XPCE/Prolog').
%cmd(productversion, '3.1') :- pwtrue.
%cmd(productversion, '4.9.3').          % dynamic!

%   Hyperlink global object references like =|@pce|=, =|@nil|=, ...
%   into their dedicated section in the Objects chapter. The
%   sty_xpce-side label =|sec:object-<safe>|= mirrors what
%   doc_latex emits for the matching =|{#object-<safe>}|= heading
%   in =|objects.md|=. If no such section exists, ltx2htm leaves
%   the lref unresolved and the bold inner content shows through.
cmd(objectname({Name}), #lref(Label, #b([nospace(@), Name]))) :-
    raw_anchor_part(Name, Name1),
    clean_anchor_part(Name1, Safe),
    atom_concat('sec:object-', Safe, Label).
cmd(noclass({Name}),            #b(Name)).
%   Anchor scheme: the .md-generated reference manual labels each
%   class chapter "sec:class-<name>" via the {#class-<name>} attribute
%   on its top-level heading; the hand-written UserGuide should label
%   its \classsummary entries with the same anchor (it was previously
%   "class:<name>"; existing .tex files need updating).

cmd(class({Name}),              #lref(Label, Name)) :-
    class_section_label(Name, Label),
    add_to_index(Name).
cmd(classs({Name}),             #lref(Label, NameS)) :-
    class_section_label(Name, Label),
    atom_concat(Name, s, NameS),
    add_to_index(Name).

%   PlDoc's section_label/1 strips underscores via
%   delete_unsafe_label_chars/2 before emitting \label{...}. Match
%   that here so links to `class-foo_bar` find `sec:class-foobar`.

class_section_label(Name, Label) :-
    atom_chars(Name, NameChars),
    delete(NameChars, '_', SafeChars),
    atom_chars(Safe, SafeChars),
    atom_concat('sec:class-', Safe, Label).
cmd(tool({Name}),               #strong(+Name)).
cmd(demo({Name}),               #strong(+Name)).
cmd(type({Name}),               #b([#code(+Name)])).
cmd(send({Name}),               #b([#code(nospace(->)), Name])).
cmd(get({Name}),                #b([#code(nospace(<-)), Name])).
cmd(both({Name}),               #b([#code(nospace(<->)), Name])).
cmd(classsend({Class}, {Name}),
    #lref(Label, #b([+Class, #code(nospace(->)), +Name]))) :-
    member_anchor(Class, send, Name, Label).
cmd(classget({Class}, {Name}),
    #lref(Label, #b([+Class, #code(nospace(<-)), +Name]))) :-
    member_anchor(Class, get, Name, Label).
cmd(classboth({Class}, {Name}),
    #lref(Label, #b([+Class, #code(nospace(<->)), +Name]))) :-
    member_anchor(Class, both, Name, Label).
cmd(sendmethod(_M, {Class}, {Selector}, {Args}),
    #defitem(pubdef,
             [ html(ObjTag), html('</a>'),
               #label(BothAlias, []),       % inline \classboth{...} fallback
               #label(Label,
                  [ #strong([Class, ' ', nospace('->'), Selector, nospace(':')]),
                    ' ', #var(+ArgsTokens)
                  ])
             ])) :-
    member_anchor(Class, send, Selector, Label),
    member_anchor(Class, both, Selector, BothAlias),
    member_data_obj(Class, send, Selector, ObjTag),
    args_tokens(Args, ArgsTokens),
    add_to_index(Label, +Label).
cmd(getmethod(_M, {Class}, {Selector}, {Args}, {Ret}),
    #defitem(pubdef,
             [ html(ObjTag), html('</a>'),
               #label(BothAlias, []),       % inline \classboth{...} fallback
               #label(Label,
                  [ #strong([Class, ' ', nospace('<-'), Selector, nospace(':')]),
                    ' ', #var(+ArgsTokens),
                    ' ', nospace('->'), ' ', #var(+RetTokens)
                  ])
             ])) :-
    member_anchor(Class, get, Selector, Label),
    member_anchor(Class, both, Selector, BothAlias),
    member_data_obj(Class, get, Selector, ObjTag),
    args_tokens(Args, ArgsTokens),
    args_tokens(Ret,  RetTokens),
    add_to_index(Label, +Label).
cmd(bothmethod(_M, {Class}, {Selector}, {Args}),
    #defitem(pubdef,
             [ html(ObjTag), html('</a>'),
               #label(SendAlias, []),       % so classsend{Class}{Sel}
               #label(GetAlias,  []),       % so classget{Class}{Sel}
               #label(Label,
                  [ #strong([Class, ' ', nospace('<->'), Selector, nospace(':')]),
                    ' ', #var(+ArgsTokens)
                  ])
             ])) :-
    member_anchor(Class, both, Selector, Label),
    member_anchor(Class, send, Selector, SendAlias),
    member_anchor(Class, get,  Selector, GetAlias),
    member_data_obj(Class, both, Selector, ObjTag),
    args_tokens(Args, ArgsTokens),
    add_to_index(Label, +Label).
%   Instance variable rendered with its documented access. All four
%   variants index under =|xpce(C, ivar, N)|= so the index has one
%   bucket per ivar regardless of which access notation the author
%   used. Each variant emits anchors for every access form
%   (=|class-C-send-N|=, =|class-C-get-N|=, =|class-C-both-N|=, and
%   the primary =|class-C-ivar-N|=) so inline references using any
%   of the arrow forms still resolve.

cmd(ivarbothmethod(_M, {Class}, {Selector}, {Args}), DOM) :-
    ivar_def(Class, Selector, Args, [' ', nospace('<->'), ' '], DOM).
cmd(ivargetmethod(_M, {Class}, {Selector}, {Args}), DOM) :-
    ivar_def(Class, Selector, Args, [' ', nospace('<-'), ' '], DOM).
cmd(ivarsendmethod(_M, {Class}, {Selector}, {Args}), DOM) :-
    ivar_def(Class, Selector, Args, [' ', nospace('->'), ' '], DOM).
cmd(ivarnonemethod(_M, {Class}, {Selector}, {Args}), DOM) :-
    ivar_def(Class, Selector, Args, [nospace('-')], DOM).

ivar_def(Class, Selector, Args, AccessVisible,
         #defitem(pubdef,
                  [ html(ObjTag), html('</a>'),
                    #label(SendAlias, []),
                    #label(GetAlias,  []),
                    #label(BothAlias, []),
                    #label(Label,
                       [ #strong([Class | AccessVisible0]),
                         ' ', #var(+ArgsTokens)
                       ])
                  ])) :-
    append(AccessVisible, [Selector, nospace(':')], AccessVisible0),
    member_anchor(Class, ivar, Selector, Label),
    member_anchor(Class, send, Selector, SendAlias),
    member_anchor(Class, get,  Selector, GetAlias),
    member_anchor(Class, both, Selector, BothAlias),
    member_data_obj(Class, ivar, Selector, ObjTag),
    args_tokens(Args, ArgsTokens),
    add_to_index(Label, +Label).
cmd(classvarmethod(_M, {Class}, {Var}, {Args}),
    #defitem(pubdef,
             [ html(ObjTag), html('</a>'),
               #label(Label,
                  [ #strong([Class, nospace('.'), Var, nospace(':')]),
                    ' ', #var(+ArgsTokens)
                  ])
             ])) :-
    member_anchor(Class, classvar, Var, Label),
    member_data_obj(Class, classvar, Var, ObjTag),
    args_tokens(Args, ArgsTokens),
    add_to_index(Label, +Label).

%   Tokenise the args atom of a class member into TeX tokens before
%   handing it to translate/3 via =|+ArgsTokens|=. Without this,
%   xpce's rich arg shapes (=|name=name|=, =|[int]|=, =|\Sbar{}|=...)
%   trip translate's =|translate(X) failed in mode "normal"|= path
%   because the atom is neither =|[]|= nor =|[H|T]|=.

args_tokens('',   []) :- !.
args_tokens(List, List) :-
    is_list(List),
    !.
args_tokens(Atom, Tokens) :-
    tex:tex_atom_to_tokens(Atom, Tokens).

%   Anchor naming scheme for class members. Mirrors the class-chapter
%   anchor (sec:class-<name>): "class-<C>-<kind>-<S>" where C and S
%   have their underscores stripped (PlDoc's section_label/1 strips
%   them when emitting \label{}, so we have to match here for cross-
%   document hyperlinks to resolve).

member_anchor(C, K, S, Label) :-
    clean_anchor_part(C, C1),
    raw_anchor_part(S, S1),
    format(atom(Label), 'class-~w-~w-~w', [C1, K, S1]).

%   The parsed arg may be a bare atom (e.g. =frame=) or a one-element
%   list (=|[frame]|=) depending on how ltx2htm tokenised the brace
%   group. Normalise, then strip underscores so cross-document
%   hyperlinks match PlDoc's section_label/1 scrubbing.

clean_anchor_part(In, Out) :-
    raw_anchor_part(In, Atom),
    atom_chars(Atom, Chars),
    delete(Chars, '_', Safe),
    atom_chars(Out, Safe).

%   Build a "<a data-obj=\"xpce(C,K,S)\">" opening tag for the
%   manindex.db SGML walker (packages/pldoc/man_index.pl). The walker
%   takes the first <a> with a data-obj attribute inside a
%   <dt class="pubdef">, so we emit a self-contained anchor before the
%   visible #label one. Underscores are preserved here -- they must
%   match the actual class and selector names so
%   pldoc:atom_to_object/2 can round-trip the term.

member_data_obj(C, K, S, Tag) :-
    raw_anchor_part(C, C1),
    raw_anchor_part(S, S1),
    format(atom(Tag),
           '<a data-obj="xpce(~q,~w,~q)">',
           [C1, K, S1]).

raw_anchor_part(In, Atom) :-
    (   atom(In)         -> Atom = In
    ;   In = [A], atom(A) -> Atom = A
    ;   atomic_list_concat(In, '', Atom)
    ).
cmd(manualtool({Descr}, {Menu}),
    #defitem([ #strong(+Descr), ' ', #i(#embrace(+Menu))])).
cmd(secoverview({Label}, {Title}),
    [ html('<li>'), #lref(RefName, +Title) ]) :-
    format(string(RefName), 'sec:~w', Label).
cmd(classsummary(_M, {RawClass}, {Args}, {_FigRef}),
    #defitem(#label(Label, [#strong(Class), #embrace(#var(+Args))]))) :-
    clean_tt(RawClass, Class),
    atom_concat('class:', Class, Label),
    add_to_index(Class, +Label).
cmd(fontalias({Alias}, {Term}), #defitem([#code(Alias), #i(+Term)])).
cmd(noargpredicate(Name), HTML) :-
    cmd(predicate(Name, {'0'}, {[]}), HTML).
%cmd(idx({Term}), nospace(Term)) :-     % If only index to section is wanted
%       add_to_index(Term).
cmd(glossitem({Term}), #defitem(#label(RefName, #strong(Term)))) :-
    canonicalise_glossitem(Term, Ref),
    format(string(RefName), 'gloss:~w', [Ref]).
cmd(g({Term}),  #lref(RefName, Term)) :-
    canonicalise_glossitem(Term, Ref),
    format(string(RefName), 'gloss:~w', [Ref]).
cmd(line({Tokens}), #quote(Line)) :-
    translate(Tokens, normal, Line).
cmd(classvar({Class}, {Var}),
    #lref(Label, #b([+Class, #code(nospace('.')), +Var]))) :-
    member_anchor(Class, classvar, Var, Label).
cmd(classinstvar({Class}, {Var}),
    #lref(Label, #b([+Class, #code(nospace('-')), +Var]))) :-
    member_anchor(Class, ivar, Var, Label).
cmd(errid({Id}), #lref(Label, #b([nospace('!'), +Id]))) :-
    error_anchor(Id, Label).

%   Anchor for error sections written by export_md.pl as
%   =|{#error-<id>}|=. Underscores survive the slug -- it must
%   match the safe_id/2 stripping pce_html_manual uses to
%   compute the section's =|sec:error-<id>|= label.

error_anchor(In, Label) :-
    clean_anchor_part(In, Id),
    atom_concat('sec:error-', Id, Label).
cmd(tab, #code(verb('\t'))).
cmd(opt({Arg}), #embrace("[]", +Arg)).
cmd(zom({Arg}), #embrace("{}", +Arg)).
cmd(fnm({Mark}), +Mark).
cmd(hr, html('<hr>')).
cmd(nameof({Names}), #embrace("{}", #code(Names))).

cmd(setupfancyplain, []).

env(tabularlp(_, Tokens), HTML) :-
    translate_table('|l|p{3in}|', Tokens, HTML).

canonicalise_glossitem(In, Out) :-
    downcase_atom(In, In1),
    atom_codes(In1, Chars0),
    (   append(Chars1, "s", Chars0)
    ->  true
    ;   Chars1 = Chars0
    ),
    maplist(canonical_char, Chars1, Chars2),
    atom_codes(Out, Chars2).

canonical_char(0' , 0'-) :- !.
canonical_char(0'_, 0'-) :- !.
canonical_char(X, X).

