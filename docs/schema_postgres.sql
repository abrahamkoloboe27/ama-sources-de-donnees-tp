-- =====================================================================
--  Schéma de la base PostgreSQL « gestion scolaire » (Supabase)
-- =====================================================================
--  ⚠️ À LIRE, PAS À EXÉCUTER : ce fichier sert de documentation.
--  L'ordre des tables et certaines contraintes ne permettent pas de le rejouer tel quel,
--  et la base du TP est partagée : on ne fait QUE des SELECT.
--
--  Comment lire ce schéma :
--   - PRIMARY KEY (clé primaire) : identifiant unique de chaque ligne (souvent « id »).
--   - FOREIGN KEY ... REFERENCES (clé étrangère) : lien vers une autre table
--     (ex. villes.pays_id → pays.id). La base refuse une ville dont le pays n'existe pas.
--   - CHECK : règle de validité (valeurs autorisées, note >= 0, etc.).
--   - UNIQUE : pas de doublon possible sur cette colonne.
--   - Le schéma est imposé « à l'écriture » (cours, partie 3) : c'est ce qui garantit la qualité.
--
--  Chaîne des liens principaux :
--   pays ← villes ← ecoles ← classes ← inscriptions → eleves
--                              classes ← evaluations ← notes → eleves
--                              classes ← bulletins → eleves
--
--  💡 Valeurs AUTORISÉES par les contraintes CHECK mais ABSENTES des données :
--   - ecoles.niveau_ecole = 'mixte'
--   - inscriptions.statut  = 'transfere', 'abandonne', 'diplome'  (seuls 'actif' et 'redoublant' existent)
--   - evaluations.type_evaluation = 'examen'                      (seuls 'devoir', 'composition', 'interrogation')
--   → le schéma dit ce qui est possible, seules les données disent ce qui existe.
--
--  💡 Index : chaque clé primaire / contrainte UNIQUE crée un index automatiquement.
--   Les index secondaires (idx_...) sont listés en fin de fichier.
--   Il n'y a PAS d'index sur notes.date_saisie : une extraction incrémentale
--   « WHERE date_saisie > ... » parcourt donc toute la table (≈ 1,2 M lignes).
-- =====================================================================

CREATE TABLE public.pays (
  id integer NOT NULL DEFAULT nextval('pays_id_seq'::regclass),
  nom character varying NOT NULL UNIQUE,
  code_iso character NOT NULL UNIQUE,
  continent character varying NOT NULL,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT pays_pkey PRIMARY KEY (id)
);
CREATE TABLE public.villes (
  id integer NOT NULL DEFAULT nextval('villes_id_seq'::regclass),
  nom character varying NOT NULL,
  pays_id integer NOT NULL,
  code_postal character varying,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT villes_pkey PRIMARY KEY (id),
  CONSTRAINT villes_pays_id_fkey FOREIGN KEY (pays_id) REFERENCES public.pays(id)
);
CREATE TABLE public.ecoles (
  id integer NOT NULL DEFAULT nextval('ecoles_id_seq'::regclass),
  nom character varying NOT NULL,
  adresse character varying,
  ville_id integer NOT NULL,
  type_ecole character varying NOT NULL CHECK (type_ecole::text = ANY (ARRAY['public'::character varying, 'prive'::character varying, 'communautaire'::character varying]::text[])),
  niveau_ecole character varying NOT NULL CHECK (niveau_ecole::text = ANY (ARRAY['primaire'::character varying, 'college'::character varying, 'lycee'::character varying, 'mixte'::character varying]::text[])),
  telephone character varying,
  email character varying,
  directeur character varying,
  date_creation date,
  capacite_max integer CHECK (capacite_max > 0),
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT ecoles_pkey PRIMARY KEY (id),
  CONSTRAINT ecoles_ville_id_fkey FOREIGN KEY (ville_id) REFERENCES public.villes(id)
);
CREATE TABLE public.annees_scolaires (
  id integer NOT NULL DEFAULT nextval('annees_scolaires_id_seq'::regclass),
  libelle character varying NOT NULL UNIQUE,
  date_debut date NOT NULL,
  date_fin date NOT NULL,
  est_active boolean DEFAULT false,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT annees_scolaires_pkey PRIMARY KEY (id)
);
CREATE TABLE public.niveaux (
  id integer NOT NULL DEFAULT nextval('niveaux_id_seq'::regclass),
  nom character varying NOT NULL UNIQUE,
  ordre integer NOT NULL UNIQUE,
  cycle character varying NOT NULL CHECK (cycle::text = ANY (ARRAY['primaire'::character varying, 'college'::character varying, 'lycee'::character varying]::text[])),
  description character varying,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT niveaux_pkey PRIMARY KEY (id)
);
CREATE TABLE public.classes (
  id integer NOT NULL DEFAULT nextval('classes_id_seq'::regclass),
  nom character varying NOT NULL,
  ecole_id integer NOT NULL,
  niveau_id integer NOT NULL,
  annee_scolaire_id integer NOT NULL,
  effectif_max integer NOT NULL DEFAULT 40 CHECK (effectif_max > 0),
  salle character varying,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT classes_pkey PRIMARY KEY (id),
  CONSTRAINT classes_ecole_id_fkey FOREIGN KEY (ecole_id) REFERENCES public.ecoles(id),
  CONSTRAINT classes_niveau_id_fkey FOREIGN KEY (niveau_id) REFERENCES public.niveaux(id),
  CONSTRAINT classes_annee_scolaire_id_fkey FOREIGN KEY (annee_scolaire_id) REFERENCES public.annees_scolaires(id)
);
CREATE TABLE public.matieres (
  id integer NOT NULL DEFAULT nextval('matieres_id_seq'::regclass),
  nom character varying NOT NULL UNIQUE,
  code character varying NOT NULL UNIQUE,
  coefficient numeric NOT NULL DEFAULT 1.0 CHECK (coefficient > 0::numeric),
  cycle character varying CHECK (cycle::text = ANY (ARRAY['primaire'::character varying, 'college'::character varying, 'lycee'::character varying, 'tous'::character varying]::text[])),
  description text,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT matieres_pkey PRIMARY KEY (id)
);
CREATE TABLE public.enseignants (
  id integer NOT NULL DEFAULT nextval('enseignants_id_seq'::regclass),
  nom character varying NOT NULL,
  prenom character varying NOT NULL,
  email character varying UNIQUE,
  telephone character varying,
  genre character CHECK (genre = ANY (ARRAY['M'::bpchar, 'F'::bpchar])),
  date_naissance date,
  date_embauche date,
  specialite character varying,
  ecole_id integer,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT enseignants_pkey PRIMARY KEY (id),
  CONSTRAINT enseignants_ecole_id_fkey FOREIGN KEY (ecole_id) REFERENCES public.ecoles(id)
);
CREATE TABLE public.enseignements (
  id integer NOT NULL DEFAULT nextval('enseignements_id_seq'::regclass),
  enseignant_id integer NOT NULL,
  classe_id integer NOT NULL,
  matiere_id integer NOT NULL,
  heures_hebdo numeric DEFAULT 2.0 CHECK (heures_hebdo > 0::numeric),
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT enseignements_pkey PRIMARY KEY (id),
  CONSTRAINT enseignements_enseignant_id_fkey FOREIGN KEY (enseignant_id) REFERENCES public.enseignants(id),
  CONSTRAINT enseignements_classe_id_fkey FOREIGN KEY (classe_id) REFERENCES public.classes(id),
  CONSTRAINT enseignements_matiere_id_fkey FOREIGN KEY (matiere_id) REFERENCES public.matieres(id)
);
CREATE TABLE public.eleves (
  id integer NOT NULL DEFAULT nextval('eleves_id_seq'::regclass),
  nom character varying NOT NULL,
  prenom character varying NOT NULL,
  date_naissance date NOT NULL,
  genre character NOT NULL CHECK (genre = ANY (ARRAY['M'::bpchar, 'F'::bpchar])),
  adresse character varying,
  ville_id integer,
  email_parent character varying,
  telephone_parent character varying,
  nom_parent character varying,
  date_inscription date NOT NULL,
  nationalite character varying,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT eleves_pkey PRIMARY KEY (id),
  CONSTRAINT eleves_ville_id_fkey FOREIGN KEY (ville_id) REFERENCES public.villes(id)
);
CREATE TABLE public.inscriptions (
  id integer NOT NULL DEFAULT nextval('inscriptions_id_seq'::regclass),
  eleve_id integer NOT NULL,
  classe_id integer NOT NULL,
  annee_scolaire_id integer NOT NULL,
  date_inscription date NOT NULL,
  statut character varying NOT NULL DEFAULT 'actif'::character varying CHECK (statut::text = ANY (ARRAY['actif'::character varying, 'transfere'::character varying, 'abandonne'::character varying, 'diplome'::character varying, 'redoublant'::character varying]::text[])),
  motif_sortie character varying,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT inscriptions_pkey PRIMARY KEY (id),
  CONSTRAINT inscriptions_eleve_id_fkey FOREIGN KEY (eleve_id) REFERENCES public.eleves(id),
  CONSTRAINT inscriptions_classe_id_fkey FOREIGN KEY (classe_id) REFERENCES public.classes(id),
  CONSTRAINT inscriptions_annee_scolaire_id_fkey FOREIGN KEY (annee_scolaire_id) REFERENCES public.annees_scolaires(id)
);
CREATE TABLE public.evaluations (
  id integer NOT NULL DEFAULT nextval('evaluations_id_seq'::regclass),
  titre character varying NOT NULL,
  matiere_id integer NOT NULL,
  classe_id integer NOT NULL,
  annee_scolaire_id integer NOT NULL,
  type_evaluation character varying NOT NULL CHECK (type_evaluation::text = ANY (ARRAY['devoir'::character varying, 'composition'::character varying, 'examen'::character varying, 'interrogation'::character varying]::text[])),
  trimestre smallint NOT NULL CHECK (trimestre = ANY (ARRAY[1, 2, 3])),
  date_debut date NOT NULL,
  date_fin date,
  note_max numeric NOT NULL DEFAULT 20.0 CHECK (note_max > 0::numeric),
  coefficient numeric NOT NULL DEFAULT 1.0 CHECK (coefficient > 0::numeric),
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT evaluations_pkey PRIMARY KEY (id),
  CONSTRAINT evaluations_matiere_id_fkey FOREIGN KEY (matiere_id) REFERENCES public.matieres(id),
  CONSTRAINT evaluations_classe_id_fkey FOREIGN KEY (classe_id) REFERENCES public.classes(id),
  CONSTRAINT evaluations_annee_scolaire_id_fkey FOREIGN KEY (annee_scolaire_id) REFERENCES public.annees_scolaires(id)
);
CREATE TABLE public.notes (
  id integer NOT NULL DEFAULT nextval('notes_id_seq'::regclass),
  evaluation_id integer NOT NULL,
  eleve_id integer NOT NULL,
  note numeric NOT NULL CHECK (note >= 0::numeric),
  observation text,
  date_saisie date NOT NULL DEFAULT CURRENT_DATE,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT notes_pkey PRIMARY KEY (id),
  CONSTRAINT notes_evaluation_id_fkey FOREIGN KEY (evaluation_id) REFERENCES public.evaluations(id),
  CONSTRAINT notes_eleve_id_fkey FOREIGN KEY (eleve_id) REFERENCES public.eleves(id)
);
CREATE TABLE public.absences (
  id integer NOT NULL DEFAULT nextval('absences_id_seq'::regclass),
  eleve_id integer NOT NULL,
  classe_id integer NOT NULL,
  date_debut date NOT NULL,
  date_fin date NOT NULL,
  motif character varying,
  justifiee boolean NOT NULL DEFAULT false,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT absences_pkey PRIMARY KEY (id),
  CONSTRAINT absences_eleve_id_fkey FOREIGN KEY (eleve_id) REFERENCES public.eleves(id),
  CONSTRAINT absences_classe_id_fkey FOREIGN KEY (classe_id) REFERENCES public.classes(id)
);
CREATE TABLE public.bulletins (
  id integer NOT NULL DEFAULT nextval('bulletins_id_seq'::regclass),
  eleve_id integer NOT NULL,
  classe_id integer NOT NULL,
  annee_scolaire_id integer NOT NULL,
  trimestre smallint NOT NULL CHECK (trimestre = ANY (ARRAY[1, 2, 3])),
  moyenne_generale numeric CHECK (moyenne_generale >= 0::numeric AND moyenne_generale <= 20::numeric),
  rang integer CHECK (rang > 0),
  appreciation text,
  date_emission date,
  created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT bulletins_pkey PRIMARY KEY (id),
  CONSTRAINT bulletins_eleve_id_fkey FOREIGN KEY (eleve_id) REFERENCES public.eleves(id),
  CONSTRAINT bulletins_classe_id_fkey FOREIGN KEY (classe_id) REFERENCES public.classes(id),
  CONSTRAINT bulletins_annee_scolaire_id_fkey FOREIGN KEY (annee_scolaire_id) REFERENCES public.annees_scolaires(id)
);

-- =====================================================================
--  Contraintes d'unicité composites (créent aussi un index)
-- =====================================================================
--  villes        UNIQUE (nom, pays_id)
--  classes       UNIQUE (nom, ecole_id, annee_scolaire_id)
--  enseignements UNIQUE (enseignant_id, classe_id, matiere_id)
--  inscriptions  UNIQUE (eleve_id, annee_scolaire_id)      → un élève, une classe par année
--  notes         UNIQUE (evaluation_id, eleve_id)          → une note par élève et par évaluation
--  bulletins     UNIQUE (eleve_id, annee_scolaire_id, trimestre)

-- =====================================================================
--  Index secondaires
-- =====================================================================
CREATE INDEX idx_absences_eleve ON public.absences USING btree (eleve_id);
CREATE INDEX idx_bulletins_eleve ON public.bulletins USING btree (eleve_id);
CREATE INDEX idx_classes_annee ON public.classes USING btree (annee_scolaire_id);
CREATE INDEX idx_classes_ecole ON public.classes USING btree (ecole_id);
CREATE INDEX idx_evaluations_annee ON public.evaluations USING btree (annee_scolaire_id);
CREATE INDEX idx_evaluations_classe ON public.evaluations USING btree (classe_id);
CREATE INDEX idx_inscriptions_annee ON public.inscriptions USING btree (annee_scolaire_id);
CREATE INDEX idx_inscriptions_classe ON public.inscriptions USING btree (classe_id);
CREATE INDEX idx_inscriptions_eleve ON public.inscriptions USING btree (eleve_id);
CREATE INDEX idx_notes_eleve ON public.notes USING btree (eleve_id);
CREATE INDEX idx_notes_evaluation ON public.notes USING btree (evaluation_id);

-- =====================================================================
--  Vues (requêtes enregistrées, interrogeables comme des tables)
-- =====================================================================
-- v_moyennes_eleves : moyenne de chaque élève par matière et par année (calcul lourd : TOUJOURS filtrer)
CREATE VIEW public.v_moyennes_eleves AS
 SELECT e.id AS eleve_id,
    e.nom AS eleve_nom,
    e.prenom AS eleve_prenom,
    m.nom AS matiere,
    m.coefficient AS coefficient_matiere,
    a.libelle AS annee_scolaire,
    i.classe_id,
    c.nom AS classe_nom,
    round(sum(n.note * ev.coefficient) / NULLIF(sum(ev.coefficient), 0::numeric), 2) AS moyenne_matiere
   FROM notes n
     JOIN evaluations ev ON ev.id = n.evaluation_id
     JOIN matieres m ON m.id = ev.matiere_id
     JOIN eleves e ON e.id = n.eleve_id
     JOIN inscriptions i ON i.eleve_id = e.id AND i.annee_scolaire_id = ev.annee_scolaire_id
     JOIN classes c ON c.id = i.classe_id
     JOIN annees_scolaires a ON a.id = ev.annee_scolaire_id
  GROUP BY e.id, e.nom, e.prenom, m.nom, m.coefficient, a.libelle, i.classe_id, c.nom;

-- v_classement_classe : classement des élèves dans leur classe, par trimestre
CREATE VIEW public.v_classement_classe AS
 SELECT b.classe_id,
    c.nom AS classe_nom,
    a.libelle AS annee_scolaire,
    b.trimestre,
    e.id AS eleve_id,
    e.nom AS eleve_nom,
    e.prenom AS eleve_prenom,
    b.moyenne_generale,
    b.rang,
    b.appreciation
   FROM bulletins b
     JOIN eleves e ON e.id = b.eleve_id
     JOIN classes c ON c.id = b.classe_id
     JOIN annees_scolaires a ON a.id = b.annee_scolaire_id
  ORDER BY a.libelle, b.classe_id, b.trimestre, b.rang;

