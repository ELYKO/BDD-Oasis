/* Requête récupérant, pour un étudiant donné, toutes les notes saisies sur les évaluations des UV verrouillées.
   On retrouve des propriétés de l'étudiant, du semestre, de l'UV, de l'inscription sur l'UV et de l'évaluation.
   La colonne "semestreEnCoursDeSaisie" permet de faire la différence entre un semestre en cours (= non verrouillé)
   et un semestre passé appartenant à l'historique (= verrouillé). */
DECLARE @idEtudiant INT
SET @idEtudiant = 11750 -- Renseigner ici un id étudiant
-- Récupération de l'identifiant de la communauté
DECLARE @idCommunaute INT	= 2
-- Récupération de l'identifiant du champ "Coefficient (COEF)" sur les UE
DECLARE @idChpUE_COEF INT	--	1143
SET @idChpUE_COEF = ISNULL((SELECT TOP 1 intIdChamp FROM DYN_Champs
							WHERE strCode = 'COEF' AND strTable = 'FPC_DB_VUE' AND intIdCommu = @idCommunaute), 0)
-- Récupération de l'identifiant du champ "Note finale (NTE_FINALE)" sur les inscriptions UE
DECLARE @idChpUE_NTE_FINALE INT	-- 1383
SET @idChpUE_NTE_FINALE = ISNULL((SELECT TOP 1 intIdChamp FROM DYN_Champs
								  WHERE strCode = 'NTE_FINALE' AND strTable = 'FPC_DBINS_VUE' AND intIdCommu = @idCommunaute), 0)
-- Récupération de l'identifiant du champ "Grade ECTS réparti (GRAD_ECTS)" sur les inscriptions UE
DECLARE @idChpUE_GRAD_ECTS INT	-- 1223
SET @idChpUE_GRAD_ECTS = ISNULL((SELECT TOP 1 intIdChamp FROM DYN_Champs
								 WHERE strCode = 'GRAD_ECTS' AND strTable = 'FPC_DBINS_VUE' AND intIdCommu = @idCommunaute), 0)
-- Récupération de l'identifiant du champ "Crédit calculé ()" sur les inscriptions UE
DECLARE @idChpUE_CREDIT_CALC INT	-- 1220
SET @idChpUE_CREDIT_CALC = ISNULL((SELECT TOP 1 intIdChamp FROM DYN_Champs
								   WHERE strCode = 'CREDIT_CALC' AND strTable = 'FPC_DBINS_VUE' AND intIdCommu = @idCommunaute), 0)
/***************************************************************************************************************************************************
 ******************************************************************** V 7.0 SP2 ********************************************************************
 ***************************************************************************************************************************************************/
SELECT p.intIdUtilisateur AS 'idEtudiant', p.strNom AS 'nomEtudiant', p.strPrenom AS 'prenomEtudiant',
	   sem.intIdProcess AS 'idSemestre', sem.strNom AS 'nomSemestre',
	   (CASE WHEN (
			SELECT COUNT(*) FROM Process pro
			LEFT OUTER JOIN Evaluations BlocEval ON BlocEval.intIdProcess = pro.intIdProcess AND BlocEval.intTypeEvaluation = 1
			INNER JOIN Evaluations Eval ON Eval.intTypeEvaluation = 0 AND Eval.boolBloque = 0
											   AND ( (Eval.intIdBlocParent = BlocEval.intIdEvaluation AND Eval.intIdProcess = -1)
												  OR (Eval.intIdBlocParent = 0 AND Eval.intIdProcess = pro.intIdProcess) )
			WHERE pro.strTypeReferentiel = 'FPC'
			AND pro.strLstParents LIKE sem.strLstParents + CAST(sem.intIdProcess AS NVARCHAR(255)) + ',%'
		) = 0 THEN 'Non' ELSE 'Oui' END) AS 'semestreEnCoursDeSaisie',
	   UV.intIdProcess AS 'idUV', UV.strCode AS 'codeUV', UV.strNom AS 'nomUV', coefUV.strValeur AS 'coefUV',
	   noteUV.strValeur AS 'noteUV', gradeUV.strValeur AS 'gradeUV', gradeSaisiUV.strGrade AS 'gradeSaisiUV', creditUV.strValeur AS 'creditsUV',
	   Eval.strCode AS 'codeEval', Eval.strTitre AS 'nomEval', Eval.decCoefficient AS 'evalCoef', noteEval.strValeur AS 'noteEval'
-- Données principales de l'étudiant
FROM Eleves p
-- Inscription de l'étudiant sur une session semestre
INNER JOIN Inscription_process isem ON isem.intIdUser = p.intIdUtilisateur
-- Session semestre = session sur le référentiel ENS (= UF) de niveau 2 (= sous l'UF mère de l'arborescence)
INNER JOIN PROCESS sem ON sem.intIdProcess = isem.intIdProcess AND sem.strTypeReferentiel = 'ENS' AND sem.intNiveau = 2
-- Inscription de l'étudiant sur une session UV
INNER JOIN Inscription_process iUV ON iUV.intIdUser = isem.intIdUser
-- Session UV verrouillée = session sur le référentiel FPC (= UE) enfant de la session semestre
-- et pour laquelle toutes les évaluations sont verrouillées
INNER JOIN PROCESS UV ON UV.intIdProcess = iUV.intIdProcess AND UV.strTypeReferentiel = 'FPC'
	AND UV.strLstParents LIKE sem.strLstParents + CAST(sem.intIdProcess AS NVARCHAR(255)) + ',%'
	AND NOT EXISTS (
		SELECT * FROM Evaluations Eval
		LEFT OUTER JOIN Evaluations BlocEval ON BlocEval.intIdProcess = UV.intIdProcess AND BlocEval.intTypeEvaluation = 1
		WHERE Eval.intTypeEvaluation = 0 AND Eval.boolBloque = 0
		AND ( (Eval.intIdBlocParent = BlocEval.intIdEvaluation AND Eval.intIdProcess = -1)
		   OR (Eval.intIdBlocParent = 0 AND Eval.intIdProcess = UV.intIdProcess) )
	)
-- Avec obligatoirement une Note = Note finale de l'étudiant sur la session UV (attention c'est un format texte)
INNER JOIN DYN_Valeurs noteUV ON noteUV.intIdChamp = @idChpUE_NTE_FINALE AND noteUV.intIdRef = CAST(iUV.intIdInscription AS NVARCHAR(255))
-- Avec obligatoirement un Grade ECTS = Grade ECTS réparti de l'étudiant sur la session UV
INNER JOIN DYN_Valeurs gradeUV ON gradeUV.intIdChamp = @idChpUE_GRAD_ECTS AND gradeUV.intIdRef = CAST(iUV.intIdInscription AS NVARCHAR(255))
-- Crédits = Crédit calculé de l'étudiant sur la session UV
LEFT OUTER JOIN DYN_Valeurs creditUV ON creditUV.intIdChamp = @idChpUE_CREDIT_CALC AND creditUV.intIdRef = CAST(iUV.intIdInscription AS NVARCHAR(255))
-- Grade forcé = Grade forcé de l'étudiant sur la session UV (s'il existe)
LEFT OUTER JOIN BDN_Bulletin gradeSaisiUV ON gradeSaisiUV.intIdEleve = p.intIdUtilisateur AND gradeSaisiUV.intIdProcess = UV.intIdProcess
-- Coefficient de la session UV (attention c'est un format texte)
LEFT OUTER JOIN DYN_Valeurs coefUV ON coefUV.intIdChamp = @idChpUE_COEF AND coefUV.intIdRef = CAST(UV.intIdProcess AS NVARCHAR(255))
-- Bloc d'évaluations sur la session UV (s'il existe)
LEFT OUTER JOIN Evaluations BlocEval ON BlocEval.intIdProcess = UV.intIdProcess AND BlocEval.intTypeEvaluation = 1
-- Evaluation sur la session UV (hors rattrapage)
INNER JOIN Evaluations Eval ON Eval.intTypeEvaluation = 0 AND Eval.boolRattrapage = 0 
								   AND ( (Eval.intIdBlocParent = BlocEval.intIdEvaluation AND Eval.intIdProcess = -1)
									  OR (Eval.intIdBlocParent = 0 AND Eval.intIdProcess = UV.intIdProcess) )
-- Note de l'étudiant sur l'évaluation (attention c'est un format texte)
INNER JOIN BDN_Notes noteEval ON Eval.intIdEvaluation = noteEval.intIdEvaluation AND noteEval.intIdEleve = p.intIdUtilisateur
								  AND UV.intIdProcess = noteEval.intIdProcess
WHERE p.intIdUtilisateur = @idEtudiant
ORDER BY nomSemestre, iduv