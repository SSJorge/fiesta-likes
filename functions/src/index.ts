import {onCall, HttpsError} from "firebase-functions/v2/https";
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";
import {randomUUID} from "crypto";

initializeApp();

const db = getFirestore();

export const createParticipant = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError(
      "unauthenticated",
      "Debes iniciar sesión.",
    );
  }

  // Verificar que quien llama sea admin.
  const adminDoc = await db
    .collection("admins")
    .doc(request.auth.uid)
    .get();

  if (!adminDoc.exists) {
    throw new HttpsError(
      "permission-denied",
      "Solo el administrador puede crear participantes.",
    );
  }

  const displayName =
    String(request.data.displayName ?? "").trim();

  const password =
    String(request.data.password ?? "");

  if (displayName.length < 2) {
    throw new HttpsError(
      "invalid-argument",
      "El nombre debe tener al menos 2 caracteres.",
    );
  }

  if (displayName.length > 40) {
    throw new HttpsError(
      "invalid-argument",
      "El nombre es demasiado largo.",
    );
  }

  if (password.length < 6) {
    throw new HttpsError(
      "invalid-argument",
      "La contraseña debe tener al menos 6 caracteres.",
    );
  }

  const loginKey = displayName.toLowerCase();

  if (loginKey.includes("/")) {
    throw new HttpsError(
      "invalid-argument",
      "El nombre no puede contener /.",
    );
  }

  const aliasRef = db
    .collection("loginAliases")
    .doc(loginKey);

  const existingAlias = await aliasRef.get();

  if (existingAlias.exists) {
    throw new HttpsError(
      "already-exists",
      "Ya existe una cuenta con ese nombre.",
    );
  }

  const internalEmail =
    `p-${randomUUID()}@fiesta.example.com`;

  const userRecord = await getAuth().createUser({
    email: internalEmail,
    password,
    displayName,
  });

  try {
    const batch = db.batch();

    batch.set(
      db.collection("profiles").doc(userRecord.uid),
      {
        displayName,
        createdAt: FieldValue.serverTimestamp(),
      },
    );

    batch.set(aliasRef, {
      uid: userRecord.uid,
      email: internalEmail,
    });

    await batch.commit();

    return {
      uid: userRecord.uid,
      displayName,
    };
  } catch (error) {
    // Si Firestore falla, no dejamos una cuenta huérfana en Auth.
    await getAuth().deleteUser(userRecord.uid);

    throw new HttpsError(
      "internal",
      "No se pudo crear el participante.",
    );
  }
});